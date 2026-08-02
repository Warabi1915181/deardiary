//
//  ToDoView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 02/05/2026.
//

import SwiftUI
import UIKit

struct ToDoView: View {
  enum Segment: String, CaseIterable {
    case active = "Dreaming"
    case completed = "Done"

    var status: ToDoStatus {
      switch self {
      case .active: return .active
      case .completed: return .completed
      }
    }
  }

  /// Coordinate space the reorder measures everything in: row frames, section
  /// frames, and the drag gesture all resolve against the scrolling content.
  private static let listSpace = "ourListContent"

  var store: ToDoStore
  var diaryStore: DiaryStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var selectedSegment: Segment = .active
  @State private var showingNewItemSheet = false
  @State private var showingNewCategorySheet = false
  @State private var showingRenameCategorySheet = false
  @State private var categoryForRename: ToDoCategory?
  @State private var reorder = ToDoReorderModel()
  @State private var scrollPosition = ScrollPosition()
  @State private var pendingCompletionIDs: Set<UUID> = []
  @State private var bridgingItem: ToDoItem?

  init(store: ToDoStore = ToDoStore(), diaryStore: DiaryStore = DiaryStore()) {
    self.store = store
    self.diaryStore = diaryStore
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(handwritten: "Our List")
          .font(.screenTitle)
          .foregroundStyle(Color("RomanceForeground"))

        Picker("Status", selection: $selectedSegment) {
          ForEach(Segment.allCases, id: \.self) { segment in
            Text(segment.rawValue).tag(segment)
          }
        }
        .pickerStyle(.segmented)

        if visibleItemsCount == 0 {
          emptyState
        } else {
          categorySections
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
      .onGeometryChange(for: ToDoReorderModel.ContentAnchor.self) { proxy in
        ToDoReorderModel.ContentAnchor(
          listY: proxy.frame(in: .named(Self.listSpace)).minY,
          screenY: proxy.frame(in: .global).minY
        )
      } action: { anchor in
        reorder.setAnchor(anchor)
      }
    }
    .onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .global)
    } action: { rect in
      reorder.setListFrame(rect)
    }
    .coordinateSpace(.named(Self.listSpace))
    .gesture(reorderGesture)
    .scrollDisabled(reorder.isDragging)
    .scrollPosition($scrollPosition)
    .onScrollGeometryChange(for: ToDoReorderModel.ScrollMetrics.self) { geometry in
      ToDoReorderModel.ScrollMetrics(
        offsetY: geometry.contentOffset.y,
        containerHeight: geometry.containerSize.height,
        contentHeight: geometry.contentSize.height,
        topInset: geometry.contentInsets.top,
        bottomInset: geometry.contentInsets.bottom
      )
    } action: { _, metrics in
      reorder.scrollChanged(metrics)
    }
    .overlay {
      if let item = reorder.draggedItem, let lift = reorder.lift {
        FloatingToDoCard(
          item: item,
          status: selectedSegment.status,
          hasLinkedMemory: linkedEntryExists(for: item),
          reduceMotion: reduceMotion
        )
        .frame(width: lift.rowRect.width)
        .position(x: lift.rowRect.midX, y: reorder.cardViewportY)
        .allowsHitTesting(false)
        .transition(.opacity)
      }
    }
    .task(id: reorder.isDragging) {
      await runAutoScroll()
    }
    // A drag can only survive while the list it measured is still on screen.
    .onChange(of: selectedSegment) { reorder.cancel() }
    .onDisappear { reorder.cancel() }
    .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: reorder.liftCount)
    .sensoryFeedback(.selection, trigger: reorder.shuffleCount)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: reorder.dropCount)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("New Idea", systemImage: "sparkles") {
            showingNewItemSheet = true
          }
          Button("New Category", systemImage: "folder.badge.plus") {
            showingNewCategorySheet = true
          }
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color("RomanceForeground"))
        }
      }
    }
    .sheet(isPresented: $showingNewItemSheet) {
      NewToDoSheet(store: store)
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showingNewCategorySheet) {
      NewCategorySheet(store: store)
        .presentationDetents([.fraction(0.35)])
    }
    .sheet(isPresented: $showingRenameCategorySheet, onDismiss: {
      categoryForRename = nil
    }) {
      if let categoryForRename {
        RenameCategorySheet(store: store, category: categoryForRename)
          .presentationDetents([.fraction(0.35)])
      }
    }
    .sheet(item: $bridgingItem) { item in
      memoryBridgeEditor(for: item)
    }
  }

  /// The memory bridge: a finished bucket item opens a diary entry — either the
  /// one already linked to it, or a fresh entry prefilled with the item's title
  /// that links back on save. Optional: the item stays "Done" whether or not a
  /// memory is ever written. Mirrors the milestone→diary bridge.
  @ViewBuilder
  private func memoryBridgeEditor(for item: ToDoItem) -> some View {
    if
      let entryID = item.linkedDiaryEntryID,
      let entry = diaryStore.entryRecord(id: entryID)
    {
      DiaryEntryEditorView(store: diaryStore, entry: entry)
    } else {
      DiaryEntryEditorView(
        store: diaryStore,
        prefillTitle: item.title,
        prefillDate: item.completedAt ?? Date(),
        onSaved: { newEntryID in
          _ = store.setLinkedDiaryEntryID(item.id, entryID: newEntryID)
        }
      )
    }
  }

  private func linkedEntryExists(for item: ToDoItem) -> Bool {
    guard let entryID = item.linkedDiaryEntryID else { return false }
    return diaryStore.entryRecord(id: entryID) != nil
  }

  private var categorySections: some View {
    VStack(spacing: 12) {
      ForEach(store.categories) { category in
        let items = reorder.displayItems(
          for: category.id,
          storeItems: store.items(for: selectedSegment.status, in: category.id)
        )
        VStack(alignment: .leading, spacing: 8) {
          ToDoCategoryHeader(
            category: category,
            canManage: category.id != ToDoStore.uncategorizedCategoryID,
            onRename: {
              categoryForRename = category
              showingRenameCategorySheet = true
            },
            onDelete: {
              store.deleteCategory(id: category.id)
            }
          )

          let slots = reorderSlots(for: category, items: items)
          VStack(spacing: ToDoReorderModel.rowSpacing) {
            // A section holding nothing but the collapsed lifted row still
            // reads as empty, so it keeps its placeholder. The rows are always
            // rendered alongside it — dropping the lifted one from the
            // hierarchy would take the in-flight gesture with it.
            if slots.allSatisfy({ $0.isCollapsed(draggingItemID: reorder.draggingItemID) }) {
              Text(selectedSegment == .active ? "No dreams here yet." : "Nothing done here yet.")
                .font(.metadata)
                .foregroundStyle(Color("PlumForeground"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            ForEach(slots) { slot in
              switch slot {
              case let .row(item): itemRow(item)
              case let .gap(height): Color.clear.frame(height: height)
              }
            }
          }
          .padding(12)
          .background(categoryBackground(for: category))
          // Only the gap moving animates here; the floating card tracks the
          // finger frame-for-frame and must stay out of this animation.
          .animation(shuffleAnimation, value: slots.map(\.id))
        }
        .onGeometryChange(for: CGRect.self) { proxy in
          proxy.frame(in: .named(Self.listSpace))
        } action: { rect in
          reorder.setCategoryFrame(rect, for: category.id)
        }
      }
    }
  }

  /// A section's rows with the drop gap spliced in. The lifted card stays in
  /// this list at its original position but collapses to nothing, so the gap
  /// alone expresses where it will land — including in another section.
  private func reorderSlots(for category: ToDoCategory, items: [ToDoItem]) -> [ToDoSlot] {
    var slots = items.map { ToDoSlot.row($0) }
    guard let gapIndex = reorder.gapIndex(for: category.id) else { return slots }

    var remaining = gapIndex
    var insertAt = slots.count
    for (offset, slot) in slots.enumerated() {
      guard case let .row(item) = slot, item.id != reorder.draggingItemID else { continue }
      if remaining == 0 {
        insertAt = offset
        break
      }
      remaining -= 1
    }
    slots.insert(.gap(reorder.liftHeight), at: insertAt)
    return slots
  }

  private func itemRow(_ item: ToDoItem) -> some View {
    ToDoItemRow(
      item: item,
      isPendingCompletion: pendingCompletionIDs.contains(item.id),
      status: selectedSegment.status,
      hasLinkedMemory: linkedEntryExists(for: item),
      onToggleComplete: {
        toggle(item: item)
      },
      onWriteMemory: {
        bridgingItem = item
      },
      onDelete: {
        withAnimation(.easeInOut(duration: 0.2)) {
          store.deleteItem(id: item.id)
        }
      }
    )
    // The lifted card is drawn in the overlay instead. Its row stays in the
    // hierarchy — destroying it would take the in-flight gesture with it — but
    // collapses away so only the gap marks where the card will land. The
    // negative padding cancels the stack spacing the empty row would leave.
    .modifier(CollapsedWhileLifted(isLifted: reorder.draggingItemID == item.id))
    .onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .named(Self.listSpace))
    } action: { rect in
      reorder.setRowFrame(rect, for: item.id)
    }
  }

  private func categoryBackground(for category: ToDoCategory) -> some View {
    let isTarget = reorder.isDropTarget(category.id)
    return RoundedRectangle(cornerRadius: 12)
      .fill(Color("RomanceBackground"))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(Color("RomanceForeground").opacity(isTarget ? 0.4 : 0), lineWidth: 1)
      }
      .animation(shuffleAnimation, value: isTarget)
  }

  /// Press and hold anywhere on a card to lift it — no drag handle, and a plain
  /// tap still reaches the buttons inside the row.
  ///
  /// It hangs off the scroll view rather than off each row, which is the only
  /// placement that leaves scrolling intact: attached to the rows or to the
  /// content, the scroll view defers its own pan to this gesture and the list
  /// stops scrolling altogether. The trade is that the scroll view wins the
  /// touch by default, so `scrollDisabled` hands it back once a card is in the
  /// air. Which card was grabbed is resolved from the press location.
  private var reorderGesture: ToDoReorderGesture {
    ToDoReorderGesture(
      coordinateSpaceName: Self.listSpace,
      onBegan: { point in
        _ = withAnimation(liftAnimation) {
          reorder.begin(at: point, buckets: currentBuckets)
        }
      },
      onChanged: { point in
        reorder.updateFinger(listY: point.y)
      },
      onEnded: {
        guard reorder.isDragging else { return }
        withAnimation(dropAnimation) {
          reorder.drop(store: store, status: selectedSegment.status)
        }
      },
      onCancelled: {
        withAnimation(dropAnimation) {
          reorder.cancel()
        }
      }
    )
  }

  /// The list as the store has it right now — the baseline a drag freezes.
  private var currentBuckets: [(id: UUID, items: [ToDoItem])] {
    store.categories.map { category in
      (category.id, store.items(for: selectedSegment.status, in: category.id))
    }
  }

  /// Nudges the list along while the finger rests near the top or bottom edge.
  private func runAutoScroll() async {
    guard reorder.isDragging else { return }
    let step = Duration.milliseconds(16)
    while !Task.isCancelled, reorder.isDragging {
      try? await Task.sleep(for: step)
      let velocity = reorder.autoScrollVelocity
      guard velocity != 0 else { continue }
      let metrics = reorder.scroll
      let proposed = metrics.offsetY + velocity * 0.016
      let clamped = reorder.clampedOffset(proposed)
      guard clamped != metrics.offsetY else { continue }
      scrollPosition.scrollTo(y: clamped + metrics.topInset)
    }
  }

  // Reduce Motion keeps the reorder legible — it is functional feedback, not
  // atmosphere — but trades the springs for a plain fade and drops the lift.
  private var liftAnimation: Animation {
    reduceMotion ? .easeInOut(duration: 0.18) : .reorderLift
  }

  private var shuffleAnimation: Animation {
    reduceMotion ? .easeInOut(duration: 0.2) : .reorderShuffle
  }

  private var dropAnimation: Animation {
    reduceMotion ? .easeInOut(duration: 0.2) : .reorderDrop
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: selectedSegment == .active ? "sparkles" : "checkmark.circle")
        .font(.system(size: 36))
        .foregroundStyle(Color("PlumForeground"))
      Text(selectedSegment == .active ? "No dreams yet." : "Nothing done yet.")
        .font(.bodyEmphasis)
        .foregroundStyle(Color("PlumForeground"))
      Text(selectedSegment == .active ? "Tap + to dream up something together." : "Finish a dream and it lands here.")
        .font(.body)
        .foregroundStyle(Color("PlumForeground"))
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("RomanceBackground"))
    )
  }

  private var visibleItemsCount: Int {
    store.categories
      .reduce(0) { partialResult, category in
        partialResult + store.items(for: selectedSegment.status, in: category.id).count
      }
  }

  private func toggle(item: ToDoItem) {
    if item.status == .active {
      pendingCompletionIDs.insert(item.id)
      withAnimation(.easeInOut(duration: 0.3)) {}
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        pendingCompletionIDs.remove(item.id)
        withAnimation(.easeInOut(duration: 0.25)) {
          store.setCompleted(item.id, completed: true)
        }
      }
      return
    }

    withAnimation(.easeInOut(duration: 0.2)) {
      store.setCompleted(item.id, completed: false)
    }
  }
}

private struct ToDoCategoryHeader: View {
  let category: ToDoCategory
  let canManage: Bool
  let onRename: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text(category.name)
        .font(.sectionHeader)
        .foregroundStyle(Color("RomanceForeground"))

      Spacer()

      if canManage {
        Menu {
          Button("Rename", systemImage: "pencil", action: onRename)
          Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 18))
            .foregroundStyle(Color("PlumForeground"))
        }
      }
    }
  }
}

/// A location-aware long press attached to the scroll view. SwiftUI's
/// `LongPressGesture.sequenced(before:)` does not expose a location until its
/// trailing drag emits a value, which delays the visual lift until the finger
/// moves. UIKit reports the location as soon as the long press begins.
private struct ToDoReorderGesture: UIGestureRecognizerRepresentable {
  let coordinateSpaceName: String
  let onBegan: (CGPoint) -> Void
  let onChanged: (CGPoint) -> Void
  let onEnded: () -> Void
  let onCancelled: () -> Void

  func makeUIGestureRecognizer(context _: Context) -> UILongPressGestureRecognizer {
    let recognizer = UILongPressGestureRecognizer()
    recognizer.minimumPressDuration = 0.3
    recognizer.allowableMovement = 12
    return recognizer
  }

  func handleUIGestureRecognizerAction(
    _ recognizer: UILongPressGestureRecognizer,
    context: Context
  ) {
    let point = context.converter.location(in: .named(coordinateSpaceName))
    switch recognizer.state {
    case .began:
      onBegan(point)
    case .changed:
      onChanged(point)
    case .ended:
      onEnded()
    case .cancelled, .failed:
      onCancelled()
    case .possible:
      break
    @unknown default:
      onCancelled()
    }
  }
}

private struct ToDoItemRow: View {
  let item: ToDoItem
  let isPendingCompletion: Bool
  let status: ToDoStatus
  let hasLinkedMemory: Bool
  let onToggleComplete: () -> Void
  let onWriteMemory: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggleComplete) {
        Image(systemName: iconName)
          .font(.system(size: 20))
          .foregroundStyle(item.status == .active ? Color("SageForeground") : Color("PlumForeground"))
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.body)
          .foregroundStyle(Color("RomanceForeground"))
          .strikethrough(status == .completed)
        if !item.details.isEmpty {
          Text(item.details)
            .font(.metadata)
            .foregroundStyle(Color("PlumForeground"))
            .lineLimit(2)
        }
        if status == .active, let targetDate = item.targetDate {
          metadataChip(icon: "calendar", text: targetDate.formatted(date: .abbreviated, time: .omitted))
        }
        if status == .completed {
          doneFooter
        }
      }

      Spacer(minLength: 8)

      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
          .font(.system(size: 16))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color("PlumForeground"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("SurfaceMuted"))
    )
  }

  /// Done rows show when the dream was finished and an optional invitation to
  /// write the moment down as a diary memory (or reopen the one already linked).
  private var doneFooter: some View {
    HStack(spacing: 8) {
      if let completedAt = item.completedAt {
        metadataChip(icon: "checkmark.seal", text: completedAt.formatted(date: .abbreviated, time: .omitted))
      }
      Button(action: onWriteMemory) {
        HStack(spacing: 4) {
          Image(systemName: hasLinkedMemory ? "book.closed" : "square.and.pencil")
          Text(hasLinkedMemory ? "View memory" : "Write it down")
        }
        .font(.metadata)
        .foregroundStyle(Color("RomanceForeground"))
      }
      .buttonStyle(.plain)
    }
    .padding(.top, 4)
  }

  private func metadataChip(icon: String, text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
      Text(text)
    }
    .font(.metadata)
    .foregroundStyle(Color("PlumForeground"))
  }

  private var iconName: String {
    if status == .completed {
      return "checkmark.circle.fill"
    }
    return isPendingCompletion ? "checkmark.circle.fill" : "circle"
  }
}

private struct NewToDoSheet: View {
  @Environment(\.dismiss) private var dismiss
  var store: ToDoStore

  @State private var title = ""
  @State private var details = ""
  @State private var selectedCategoryID: UUID = ToDoStore.uncategorizedCategoryID
  @State private var hasTargetDate = false
  @State private var targetDate = Date()
  @State private var showValidationError = false

  var body: some View {
    NavigationStack {
      Form {
        TextField("Dream title", text: $title)
          .font(.body)
        TextField("Notes (optional)", text: $details)
          .font(.body)
        Picker("Category", selection: $selectedCategoryID) {
          ForEach(store.categories) { category in
            Text(category.name).tag(category.id)
          }
        }
        .pickerStyle(.navigationLink)
        Toggle("Set a date", isOn: $hasTargetDate)
          .font(.body)
        if hasTargetDate {
          DatePicker("When", selection: $targetDate, displayedComponents: [.date])
            .font(.body)
        }
      }
      .navigationTitle("New Idea")
      .onAppear {
        if !store.categories.contains(where: { $0.id == selectedCategoryID }) {
          selectedCategoryID = store.categories.first?.id ?? ToDoStore.uncategorizedCategoryID
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add") {
            let added = store.addItem(
              title: title,
              details: details,
              categoryID: selectedCategoryID,
              targetDate: hasTargetDate ? targetDate : nil
            )
            if added {
              dismiss()
            } else {
              showValidationError = true
            }
          }
        }
      }
      .alert("Title required", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Please enter a title.")
      }
    }
  }
}

private struct NewCategorySheet: View {
  @Environment(\.dismiss) private var dismiss
  var store: ToDoStore
  @State private var categoryName = ""
  @State private var showValidationError = false

  var body: some View {
    NavigationStack {
      Form {
        TextField("Category name", text: $categoryName)
          .font(.body)
      }
      .navigationTitle("New Category")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add") {
            let created = store.addCategory(name: categoryName)
            if created {
              dismiss()
            } else {
              showValidationError = true
            }
          }
        }
      }
      .alert("Invalid category", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Category must be non-empty and unique.")
      }
    }
  }
}

private struct RenameCategorySheet: View {
  @Environment(\.dismiss) private var dismiss
  var store: ToDoStore
  let category: ToDoCategory
  @State private var categoryName: String
  @State private var showValidationError = false

  init(store: ToDoStore, category: ToDoCategory) {
    self.store = store
    self.category = category
    _categoryName = State(initialValue: category.name)
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Category name", text: $categoryName)
          .font(.body)
      }
      .navigationTitle("Rename Category")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") {
            let renamed = store.renameCategory(id: category.id, newName: categoryName)
            if renamed {
              dismiss()
            } else {
              showValidationError = true
            }
          }
        }
      }
      .alert("Invalid category", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Category must be non-empty and unique.")
      }
    }
  }
}

/// One entry in a section's stack: either a real row, or the gap the lifted
/// card will drop into.
private enum ToDoSlot: Identifiable {
  case row(ToDoItem)
  case gap(CGFloat)

  var id: String {
    switch self {
    case let .row(item): item.id.uuidString
    case .gap: "reorder-gap"
    }
  }

  /// True when this slot takes up no space — the lifted card's own row.
  func isCollapsed(draggingItemID: UUID?) -> Bool {
    guard case let .row(item) = self else { return false }
    return item.id == draggingItemID
  }
}

/// Collapses the lifted card's row out of the stack without removing it, so the
/// gesture it hosts stays alive for the rest of the drag.
private struct CollapsedWhileLifted: ViewModifier {
  let isLifted: Bool

  func body(content: Content) -> some View {
    content
      .opacity(isLifted ? 0 : 1)
      .frame(height: isLifted ? 0 : nil)
      .clipped()
      .padding(.vertical, isLifted ? -ToDoReorderModel.rowSpacing / 2 : 0)
  }
}

/// The card that follows the finger. It is a copy of the row rendered above the
/// scroll view, so it can cross section boundaries without being clipped, and
/// it grows into its lifted state on appear rather than popping in already big.
private struct FloatingToDoCard: View {
  let item: ToDoItem
  let status: ToDoStatus
  let hasLinkedMemory: Bool
  let reduceMotion: Bool

  @Environment(\.colorScheme) private var colorScheme
  @State private var lifted = false

  var body: some View {
    ToDoItemRow(
      item: item,
      isPendingCompletion: false,
      status: status,
      hasLinkedMemory: hasLinkedMemory,
      onToggleComplete: {},
      onWriteMemory: {},
      onDelete: {}
    )
    .overlay(
      // Elevation follows the house convention: a warm-tinted shadow by
      // Morning, and — since Warm Shadow resolves to clear at night — an ember
      // rim doing the lifting in Candlelight.
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              Color("RomanceForeground").opacity(0.32),
              Color("RomanceForeground").opacity(0.06),
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
        .opacity(colorScheme == .dark ? (lifted ? 1 : 0) : 0)
    )
    .scaleEffect(lifted ? 1.03 : 1)
    .shadow(color: Color("WarmShadow").opacity(lifted ? 0.24 : 0), radius: 16, y: 8)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.reorderLift) { lifted = true }
    }
  }
}

#Preview {
  let now = Date()
  let previewState = ToDoPersistedState(
    categories: [
      ToDoCategory(
        id: ToDoStore.uncategorizedCategoryID,
        coupleSpaceID: nil,
        name: "Uncategorized",
        order: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
      ToDoCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        coupleSpaceID: nil,
        name: "Dates",
        order: 1,
        createdAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
    ],
    items: [
      ToDoItem(
        id: UUID(),
        coupleSpaceID: nil,
        title: "Plan weekend picnic",
        details: "Bring camera and blanket",
        categoryID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        status: .active,
        order: 0,
        targetDate: now.addingTimeInterval(7 * 86400),
        linkedDiaryEntryID: nil,
        createdAt: now,
        completedAt: nil,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
      ToDoItem(
        id: UUID(),
        coupleSpaceID: nil,
        title: "Watch sunset at harbor",
        details: "",
        categoryID: ToDoStore.uncategorizedCategoryID,
        status: .completed,
        order: 0,
        targetDate: nil,
        linkedDiaryEntryID: nil,
        createdAt: now,
        completedAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
    ]
  )

  Group {
    ViewWithBackdrop {
      NavigationStack {
        ToDoView(store: ToDoStore(previewState: previewState))
      }
    }
    .preferredColorScheme(.dark)
  }
}
