//
//  ToDoReorderModel.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 02/08/2026.
//

import SwiftUI

/// Everything the reorder needs from the enclosing `ScrollView` each frame.
///
/// Declared outside the model because `onGeometryChange` requires a `Sendable`
/// value, which a type nested in a `@MainActor` class cannot be.
nonisolated struct ToDoListScrollMetrics: Equatable {
  var offsetY: CGFloat = 0
  var containerHeight: CGFloat = 0
  var contentHeight: CGFloat = 0
  var topInset: CGFloat = 0
  var bottomInset: CGFloat = 0
}

/// The top of the scrolling content, measured in both list space and on screen.
///
/// `contentOffset` is not usable as a "how far has this moved" signal here — a
/// collapsing navigation title changes the inset, so the content slides further
/// than the offset says. This anchor measures the movement directly instead,
/// and doubles as the bridge between the two spaces.
nonisolated struct ToDoListContentAnchor: Equatable {
  var listY: CGFloat = 0
  var screenY: CGFloat = 0
}

/// Drives the long-press reorder on Our List.
///
/// Our List is a `ScrollView` of hand-laid-out cards rather than a `List`, so
/// there is no `onMove` to lean on. This model owns the whole interaction: it
/// freezes the list's geometry the moment a card is lifted, follows the finger,
/// and publishes a *preview* order that the view renders while the drag is
/// still in flight. The store is written once, on drop.
///
/// Freezing the geometry is the important part. Rows reflow (and therefore
/// report new frames) continuously during a drag, so measuring live would feed
/// the drag its own output and make the insertion point oscillate. Instead the
/// insertion point is always derived from the layout as it stood at lift time,
/// with the lifted card's own height subtracted from the rows that sat below
/// it — which is exactly the gap-closed layout the finger is aiming into.
@MainActor
@Observable
final class ToDoReorderModel {
  /// Vertical gap between cards inside a category, mirrored from the view.
  static let rowSpacing: CGFloat = 8

  struct Lift {
    let itemID: UUID
    let sourceCategoryID: UUID
    /// The lifted card's frame in list space, frozen at lift time.
    let rowRect: CGRect
    /// Where inside the card the finger grabbed it, so the card doesn't jump
    /// when the first drag sample arrives.
    var grabOffsetY: CGFloat
  }

  typealias ScrollMetrics = ToDoListScrollMetrics
  typealias ContentAnchor = ToDoListContentAnchor

  private(set) var lift: Lift?
  private(set) var targetCategoryID: UUID?
  private(set) var targetIndex = 0

  /// Counters the view turns into haptics via `sensoryFeedback(_:trigger:)`.
  private(set) var liftCount = 0
  private(set) var shuffleCount = 0
  private(set) var dropCount = 0

  /// The finger's position in list space — the scroll view's own frame, which
  /// stays put while the content slides through it.
  private(set) var fingerListY: CGFloat = 0
  private(set) var scroll = ScrollMetrics()
  private(set) var anchor = ContentAnchor()
  /// The scroll view's own frame on screen, used to decide when the finger has
  /// reached an edge and to place the floating card in the overlay.
  private(set) var listFrame: CGRect = .zero

  private var rowFrames: [UUID: CGRect] = [:]
  private var categoryFrames: [UUID: CGRect] = [:]
  private var frozenOrder: [UUID: [UUID]] = [:]
  private var snapshot: [UUID: ToDoItem] = [:]
  /// Where the content sat when the card was lifted. The frozen frames were
  /// measured against it, so the finger is compensated by however far the list
  /// has auto-scrolled since.
  private var liftAnchorListY: CGFloat = 0

  var isDragging: Bool { lift != nil }
  var draggingItemID: UUID? { lift?.itemID }
  var draggedItem: ToDoItem? { lift.flatMap { snapshot[$0.itemID] } }

  /// Where the floating card's centre sits within the scroll view's bounds,
  /// which is the space the overlay draws in.
  var cardViewportY: CGFloat { fingerScreenY - listFrame.minY - (lift?.grabOffsetY ?? 0) }

  /// The finger expressed in the frame of reference the frozen geometry was
  /// measured in.
  private var queryY: CGFloat { fingerListY + (liftAnchorListY - anchor.listY) }

  /// The finger on screen — list space drifts as the content scrolls, so edge
  /// detection has to be done against something that does not move.
  private var fingerScreenY: CGFloat { anchor.screenY + (fingerListY - anchor.listY) }

  // MARK: - Measurement

  func setRowFrame(_ rect: CGRect, for id: UUID) {
    guard !isDragging else { return }
    rowFrames[id] = rect
  }

  func setAnchor(_ value: ContentAnchor) {
    anchor = value
    if isDragging { recomputeTarget() }
  }

  func setListFrame(_ rect: CGRect) {
    listFrame = rect
  }

  func setCategoryFrame(_ rect: CGRect, for id: UUID) {
    guard !isDragging else { return }
    categoryFrames[id] = rect
  }

  func scrollChanged(_ metrics: ScrollMetrics) {
    scroll = metrics
    if isDragging { recomputeTarget() }
  }

  // MARK: - Rendering

  /// The order to render for a category. While a card is in flight this is the
  /// order frozen at lift: the lifted card stays parked in its own section
  /// (collapsed to nothing) rather than hopping between sections, because being
  /// re-created inside another section's `ForEach` would destroy the view that
  /// owns the in-flight gesture. The move is expressed by the gap instead.
  func displayItems(for categoryID: UUID, storeItems: [ToDoItem]) -> [ToDoItem] {
    guard isDragging, let ids = frozenOrder[categoryID] else { return storeItems }
    return ids.compactMap { snapshot[$0] }
  }

  /// Where the gap sits in `categoryID`, counted over that section's rows with
  /// the lifted card excluded. Nil for sections the card is not hovering over.
  func gapIndex(for categoryID: UUID) -> Int? {
    guard isDragging, targetCategoryID == categoryID else { return nil }
    return targetIndex
  }

  /// The height the gap should open to — the lifted card's own height.
  var liftHeight: CGFloat { lift?.rowRect.height ?? 0 }

  /// True while a card is hovering over a category it did not start in — the
  /// cue that this section is about to receive the drop.
  func isDropTarget(_ categoryID: UUID) -> Bool {
    guard let lift, targetCategoryID == categoryID else { return false }
    return lift.sourceCategoryID != categoryID
  }

  // MARK: - Drag lifecycle

  /// Lifts whichever card sits under `point`. Returns false when the press
  /// landed somewhere that is not a card, which leaves the list untouched.
  @discardableResult
  func begin(at point: CGPoint, buckets: [(id: UUID, items: [ToDoItem])]) -> Bool {
    guard lift == nil else { return false }
    guard let itemID = rowFrames.first(where: { $0.value.contains(point) })?.key else { return false }
    guard let categoryID = buckets.first(where: { $0.items.contains { $0.id == itemID } })?.id,
          let rowRect = rowFrames[itemID]
    else { return false }

    snapshot = Dictionary(uniqueKeysWithValues: buckets.flatMap(\.items).map { ($0.id, $0) })
    frozenOrder = Dictionary(uniqueKeysWithValues: buckets.map { ($0.id, $0.items.map(\.id)) })

    fingerListY = point.y
    liftAnchorListY = anchor.listY
    lift = Lift(
      itemID: itemID,
      sourceCategoryID: categoryID,
      rowRect: rowRect,
      grabOffsetY: point.y - rowRect.midY
    )
    targetCategoryID = categoryID
    targetIndex = frozenOrder[categoryID]?.firstIndex(of: itemID) ?? 0
    liftCount += 1
    return true
  }

  func updateFinger(listY: CGFloat) {
    guard lift != nil else { return }
    fingerListY = listY
    recomputeTarget()
  }

  /// Commits the previewed position to the store and puts the card down.
  func drop(store: ToDoStore, status: ToDoStatus) {
    guard let lift, let categoryID = targetCategoryID else {
      clear()
      return
    }
    // The gap sits *before* whichever row currently occupies the target index.
    let ids = (frozenOrder[categoryID] ?? []).filter { $0 != lift.itemID }
    let beforeID = ids.indices.contains(targetIndex) ? ids[targetIndex] : nil
    store.moveItem(
      id: lift.itemID,
      targetCategoryID: categoryID,
      targetStatus: status,
      before: beforeID
    )
    dropCount += 1
    clear()
  }

  func cancel() {
    guard isDragging else { return }
    clear()
  }

  private func clear() {
    lift = nil
    frozenOrder = [:]
    snapshot = [:]
    targetCategoryID = nil
    targetIndex = 0
  }

  // MARK: - Auto-scroll

  /// Points per second the list should scroll, based on how deep the finger is
  /// into the top or bottom edge zone. Zero when it is in the calm middle.
  var autoScrollVelocity: CGFloat {
    guard isDragging, listFrame.height > 0 else { return 0 }
    let zone: CGFloat = 88
    let maxSpeed: CGFloat = 600
    let top = listFrame.minY + scroll.topInset + zone
    let bottom = listFrame.maxY - scroll.bottomInset - zone
    let y = fingerScreenY

    if y < top {
      return -maxSpeed * min(1, (top - y) / zone)
    }
    if y > bottom {
      return maxSpeed * min(1, (y - bottom) / zone)
    }
    return 0
  }

  /// Clamps a proposed scroll offset to the list's real travel.
  func clampedOffset(_ proposed: CGFloat) -> CGFloat {
    let minOffset = -scroll.topInset
    let maxOffset = max(minOffset, scroll.contentHeight + scroll.bottomInset - scroll.containerHeight)
    return min(max(proposed, minOffset), maxOffset)
  }

  // MARK: - Target resolution

  private func recomputeTarget() {
    guard let lift else { return }
    let y = queryY
    let categoryID = category(containing: y) ?? targetCategoryID ?? lift.sourceCategoryID

    let ids = (frozenOrder[categoryID] ?? []).filter { $0 != lift.itemID }
    var index = ids.count
    for (offset, id) in ids.enumerated() {
      guard let midY = gapClosedMidY(of: id, in: categoryID, lift: lift) else { continue }
      if y < midY {
        index = offset
        break
      }
    }

    guard categoryID != targetCategoryID || index != targetIndex else { return }
    targetCategoryID = categoryID
    targetIndex = index
    shuffleCount += 1
  }

  /// A row's centre in the layout the finger is actually aiming into: rows that
  /// sat below the lifted card have already closed the gap it left behind.
  private func gapClosedMidY(of id: UUID, in categoryID: UUID, lift: Lift) -> CGFloat? {
    guard let rect = rowFrames[id] else { return nil }
    guard categoryID == lift.sourceCategoryID, rect.minY > lift.rowRect.minY else { return rect.midY }
    return rect.midY - (lift.rowRect.height + Self.rowSpacing)
  }

  private func category(containing y: CGFloat) -> UUID? {
    if let hit = categoryFrames.first(where: { $0.value.minY <= y && y <= $0.value.maxY })?.key {
      return hit
    }
    // Past the ends of the list, or in the gap between two sections: fall back
    // to whichever section's edge is nearest so the drop still lands somewhere.
    return categoryFrames.min(by: { lhs, rhs in
      distance(from: y, to: lhs.value) < distance(from: y, to: rhs.value)
    })?.key
  }

  private func distance(from y: CGFloat, to rect: CGRect) -> CGFloat {
    if y < rect.minY { return rect.minY - y }
    if y > rect.maxY { return y - rect.maxY }
    return 0
  }
}

extension Animation {
  /// Soft settle springs — enough life to feel physical, well short of bouncy.
  static let reorderLift = Animation.spring(response: 0.26, dampingFraction: 0.82)
  static let reorderShuffle = Animation.spring(response: 0.34, dampingFraction: 0.86)
  static let reorderDrop = Animation.spring(response: 0.34, dampingFraction: 0.88)
}
