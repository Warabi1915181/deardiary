import Foundation
import SwiftUI
import Combine

enum ToDoStatus: String, Codable, CaseIterable {
  case active
  case completed
}

struct ToDoCategory: Identifiable, Codable, Hashable {
  var id: UUID
  var name: String
  var order: Int
}

struct ToDoItem: Identifiable, Codable, Hashable {
  var id: UUID
  var title: String
  var details: String
  var categoryID: UUID
  var status: ToDoStatus
  var order: Int
  var createdAt: Date
  var completedAt: Date?
}

struct ToDoPersistedState: Codable {
  var categories: [ToDoCategory]
  var items: [ToDoItem]
}

final class ToDoStore: ObservableObject {
  static let appStorageKey = "todo.store.v1.json"
  static let uncategorizedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  @Published private(set) var state: ToDoPersistedState {
    didSet { save() }
  }

  private let userDefaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(userDefaults: UserDefaults = .standard, previewState: ToDoPersistedState? = nil) {
    self.userDefaults = userDefaults
    if let previewState {
      self.state = ToDoStore.normalize(previewState)
      return
    }

    guard
      let raw = userDefaults.string(forKey: Self.appStorageKey),
      let data = raw.data(using: .utf8),
      let decoded = try? decoder.decode(ToDoPersistedState.self, from: data)
    else {
      self.state = ToDoStore.defaultState()
      save()
      return
    }

    self.state = ToDoStore.normalize(decoded)
  }

  var categories: [ToDoCategory] {
    state.categories.sorted { lhs, rhs in
      if lhs.order == rhs.order {
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      return lhs.order < rhs.order
    }
  }

  func category(for id: UUID) -> ToDoCategory? {
    state.categories.first(where: { $0.id == id })
  }

  func items(for status: ToDoStatus, in categoryID: UUID) -> [ToDoItem] {
    state.items
      .filter { $0.status == status && $0.categoryID == categoryID }
      .sorted { lhs, rhs in lhs.order < rhs.order }
  }

  func addCategory(name: String) -> Bool {
    let normalizedName = normalizedNameFromInput(name)
    guard !normalizedName.isEmpty else { return false }
    guard !hasDuplicateCategoryName(normalizedName) else { return false }

    let nextOrder = (state.categories.map(\.order).max() ?? 0) + 1
    state.categories.append(ToDoCategory(id: UUID(), name: normalizedName, order: nextOrder))
    return true
  }

  func renameCategory(id: UUID, newName: String) -> Bool {
    guard id != Self.uncategorizedCategoryID else { return false }
    let normalizedName = normalizedNameFromInput(newName)
    guard !normalizedName.isEmpty else { return false }
    guard !hasDuplicateCategoryName(normalizedName, excluding: id) else { return false }
    guard let index = state.categories.firstIndex(where: { $0.id == id }) else { return false }
    state.categories[index].name = normalizedName
    return true
  }

  func deleteCategory(id: UUID) {
    guard id != Self.uncategorizedCategoryID else { return }
    guard let categoryIndex = state.categories.firstIndex(where: { $0.id == id }) else { return }

    state.categories.remove(at: categoryIndex)
    reindexCategoryOrder()

    for index in state.items.indices where state.items[index].categoryID == id {
      state.items[index].categoryID = Self.uncategorizedCategoryID
    }

    rebuildOrder(in: Self.uncategorizedCategoryID, status: .active)
    rebuildOrder(in: Self.uncategorizedCategoryID, status: .completed)
  }

  func addItem(title: String, details: String, categoryID: UUID) -> Bool {
    let normalizedTitle = normalizedNameFromInput(title)
    guard !normalizedTitle.isEmpty else { return false }

    let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
    let safeCategoryID = state.categories.contains(where: { $0.id == categoryID })
      ? categoryID : Self.uncategorizedCategoryID
    let nextOrder = (items(for: .active, in: safeCategoryID).map(\.order).max() ?? -1) + 1

    state.items.append(
      ToDoItem(
        id: UUID(),
        title: normalizedTitle,
        details: normalizedDetails,
        categoryID: safeCategoryID,
        status: .active,
        order: nextOrder,
        createdAt: Date(),
        completedAt: nil
      )
    )
    return true
  }

  func deleteItem(id: UUID) {
    guard let index = state.items.firstIndex(where: { $0.id == id }) else { return }
    let item = state.items[index]
    state.items.remove(at: index)
    rebuildOrder(in: item.categoryID, status: item.status)
  }

  func setCompleted(_ id: UUID, completed: Bool) {
    guard let item = state.items.first(where: { $0.id == id }) else { return }
    let targetStatus: ToDoStatus = completed ? .completed : .active
    moveItem(id: id, targetCategoryID: item.categoryID, targetStatus: targetStatus, before: nil)
    guard let index = state.items.firstIndex(where: { $0.id == id }) else { return }
    state.items[index].completedAt = completed ? Date() : nil
  }

  func moveItem(
    id: UUID,
    targetCategoryID: UUID,
    targetStatus: ToDoStatus,
    before targetItemID: UUID?
  ) {
    guard let dragged = state.items.first(where: { $0.id == id }) else { return }
    let safeCategoryID = state.categories.contains(where: { $0.id == targetCategoryID })
      ? targetCategoryID : Self.uncategorizedCategoryID

    let sourceIDs = bucketItemIDs(
      categoryID: dragged.categoryID,
      status: dragged.status,
      excluding: dragged.id
    )

    var targetIDs = bucketItemIDs(
      categoryID: safeCategoryID,
      status: targetStatus,
      excluding: dragged.id
    )

    if let targetItemID, let targetIndex = targetIDs.firstIndex(of: targetItemID) {
      targetIDs.insert(dragged.id, at: targetIndex)
    } else {
      targetIDs.append(dragged.id)
    }

    if dragged.categoryID == safeCategoryID && dragged.status == targetStatus {
      applyOrder(itemIDs: targetIDs, categoryID: safeCategoryID, status: targetStatus)
      return
    }

    applyOrder(itemIDs: sourceIDs, categoryID: dragged.categoryID, status: dragged.status)
    applyOrder(itemIDs: targetIDs, categoryID: safeCategoryID, status: targetStatus)
  }

  private func save() {
    guard let data = try? encoder.encode(state), let string = String(data: data, encoding: .utf8) else {
      return
    }
    userDefaults.set(string, forKey: Self.appStorageKey)
  }

  private func bucketItemIDs(categoryID: UUID, status: ToDoStatus, excluding id: UUID?) -> [UUID] {
    items(for: status, in: categoryID)
      .map(\.id)
      .filter { itemID in
        guard let id else { return true }
        return itemID != id
      }
  }

  private func applyOrder(itemIDs: [UUID], categoryID: UUID, status: ToDoStatus) {
    for (index, itemID) in itemIDs.enumerated() {
      guard let itemIndex = state.items.firstIndex(where: { $0.id == itemID }) else { continue }
      state.items[itemIndex].categoryID = categoryID
      state.items[itemIndex].status = status
      state.items[itemIndex].order = index
    }
  }

  private func rebuildOrder(in categoryID: UUID, status: ToDoStatus) {
    let ids = bucketItemIDs(categoryID: categoryID, status: status, excluding: nil)
    applyOrder(itemIDs: ids, categoryID: categoryID, status: status)
  }

  private func reindexCategoryOrder() {
    let regularCategories = state.categories
      .filter { $0.id != Self.uncategorizedCategoryID }
      .sorted { lhs, rhs in lhs.order < rhs.order }

    var rebuilt: [ToDoCategory] = [
      ToDoCategory(id: Self.uncategorizedCategoryID, name: "Uncategorized", order: 0)
    ]

    rebuilt += regularCategories.enumerated().map { index, category in
      ToDoCategory(id: category.id, name: category.name, order: index + 1)
    }

    state.categories = rebuilt
  }

  private func normalizedNameFromInput(_ input: String) -> String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func hasDuplicateCategoryName(_ name: String, excluding id: UUID? = nil) -> Bool {
    state.categories.contains { category in
      guard category.id != id else { return false }
      return category.name.caseInsensitiveCompare(name) == .orderedSame
    }
  }

  private static func defaultState() -> ToDoPersistedState {
    ToDoPersistedState(
      categories: [
        ToDoCategory(id: uncategorizedCategoryID, name: "Uncategorized", order: 0)
      ],
      items: []
    )
  }

  private static func normalize(_ state: ToDoPersistedState) -> ToDoPersistedState {
    var categories = state.categories
    if !categories.contains(where: { $0.id == uncategorizedCategoryID }) {
      categories.append(ToDoCategory(id: uncategorizedCategoryID, name: "Uncategorized", order: -1))
    }

    let regularCategories = categories
      .filter { $0.id != uncategorizedCategoryID }
      .sorted { lhs, rhs in lhs.order < rhs.order }
      .enumerated()
      .map { index, category in
        ToDoCategory(
          id: category.id,
          name: category.name.trimmingCharacters(in: .whitespacesAndNewlines),
          order: index + 1
        )
      }

    let normalizedCategories: [ToDoCategory] = [
      ToDoCategory(id: uncategorizedCategoryID, name: "Uncategorized", order: 0)
    ] + regularCategories

    let categoryIDs = Set(normalizedCategories.map(\.id))
    var normalizedItems = state.items.map { item in
      var mutable = item
      if !categoryIDs.contains(item.categoryID) {
        mutable.categoryID = uncategorizedCategoryID
      }
      mutable.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
      return mutable
    }

    for category in normalizedCategories {
      normalizedItems = normalizedItems.reorderedItems(
        in: category.id,
        status: .active
      )
      normalizedItems = normalizedItems.reorderedItems(
        in: category.id,
        status: .completed
      )
    }

    return ToDoPersistedState(categories: normalizedCategories, items: normalizedItems)
  }
}

private extension Array where Element == ToDoItem {
  func reorderedItems(in categoryID: UUID, status: ToDoStatus) -> [ToDoItem] {
    var output = self
    let bucket = self
      .filter { $0.categoryID == categoryID && $0.status == status }
      .sorted { $0.order < $1.order }

    for (index, item) in bucket.enumerated() {
      guard let outputIndex = output.firstIndex(where: { $0.id == item.id }) else { continue }
      output[outputIndex].order = index
    }
    return output
  }
}
