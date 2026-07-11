import Foundation

enum ToDoStatus: String, Codable, CaseIterable {
  case active
  case completed
}

struct ToDoCategory: Identifiable, Codable, Hashable, SyncStamped {
  var id: UUID
  var coupleSpaceID: UUID?
  var name: String
  var order: Int
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?
  var modifiedByDeviceID: String
  var version: Int
}

struct ToDoItem: Identifiable, Codable, Hashable, SyncStamped {
  var id: UUID
  var coupleSpaceID: UUID?
  var title: String
  var details: String
  var categoryID: UUID
  var status: ToDoStatus
  var order: Int
  var createdAt: Date
  var completedAt: Date?
  var updatedAt: Date
  var deletedAt: Date?
  var modifiedByDeviceID: String
  var version: Int
}

struct ToDoPersistedState: Codable {
  var categories: [ToDoCategory]
  var items: [ToDoItem]
}

@Observable
final class ToDoStore {
  static let schemaVersion = 1
  static let legacyAppStorageKey = "todo.store.v1.json"

  static let uncategorizedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  private(set) var state: ToDoPersistedState {
    didSet { save() }
  }

  private let storeURL: URL
  private let userDefaults: UserDefaults
  private let deviceID: String
  private let fileManager: FileManager
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  @ObservationIgnored var onRecordsChanged: ((Set<SyncRecordReference>) -> Void)?

  init(
    storeURL: URL? = nil,
    userDefaults: UserDefaults = .standard,
    deviceID: String = AppDeviceIdentifier.current(),
    fileManager: FileManager = .default,
    previewState: ToDoPersistedState? = nil
  ) {
    self.userDefaults = userDefaults
    self.deviceID = deviceID
    self.fileManager = fileManager

    let baseURL = storeURL?.deletingLastPathComponent()
      ?? Self.defaultApplicationSupportDirectory(fileManager: fileManager)
    self.storeURL = storeURL ?? baseURL.appendingPathComponent("todo.store.v1.json")

    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    if let previewState {
      self.state = Self.normalize(previewState, deviceID: deviceID)
      return
    }

    if
      let data = try? Data(contentsOf: self.storeURL),
      let decoded = try? decoder.decode(ToDoPersistedState.self, from: data)
    {
      self.state = Self.normalize(decoded, deviceID: deviceID)
      return
    }

    if let migrated = Self.loadLegacyState(from: userDefaults) {
      self.state = Self.normalize(migrated, deviceID: deviceID)
      save()
      userDefaults.removeObject(forKey: Self.legacyAppStorageKey)
      return
    }

    self.state = Self.defaultState(deviceID: deviceID)
    save()
  }

  var categories: [ToDoCategory] {
    state.categories
      .filter { $0.deletedAt == nil }
      .sorted { lhs, rhs in
        if lhs.order == rhs.order {
          return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.order < rhs.order
      }
  }

  func category(for id: UUID) -> ToDoCategory? {
    state.categories.first(where: { $0.id == id && $0.deletedAt == nil })
  }

  func items(for status: ToDoStatus, in categoryID: UUID) -> [ToDoItem] {
    state.items
      .filter { $0.status == status && $0.categoryID == categoryID && $0.deletedAt == nil }
      .sorted(by: Self.sortItems)
  }

  func addCategory(name: String, coupleSpaceID: UUID? = nil) -> Bool {
    let normalizedName = normalizedNameFromInput(name)
    guard !normalizedName.isEmpty else { return false }
    guard !hasDuplicateCategoryName(normalizedName) else { return false }

    let now = Date()
    let nextOrder = (categories.map(\.order).max() ?? 0) + 1
    let category = ToDoCategory(
      id: UUID(),
      coupleSpaceID: coupleSpaceID,
      name: normalizedName,
      order: nextOrder,
      createdAt: now,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: deviceID,
      version: Self.schemaVersion
    )
    state.categories.append(category)
    notifyChanges([SyncRecordReference(kind: .toDoCategory, id: category.id)])
    return true
  }

  func renameCategory(id: UUID, newName: String) -> Bool {
    guard id != Self.uncategorizedCategoryID else { return false }
    let normalizedName = normalizedNameFromInput(newName)
    guard !normalizedName.isEmpty else { return false }
    guard !hasDuplicateCategoryName(normalizedName, excluding: id) else { return false }
    guard let index = state.categories.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }
    state.categories[index].name = normalizedName
    touchCategory(at: index)
    notifyChanges([SyncRecordReference(kind: .toDoCategory, id: id)])
    return true
  }

  func deleteCategory(id: UUID) {
    guard id != Self.uncategorizedCategoryID else { return }
    guard let categoryIndex = state.categories.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return
    }

    let now = Date()
    state.categories[categoryIndex].deletedAt = now
    state.categories[categoryIndex].updatedAt = now
    state.categories[categoryIndex].modifiedByDeviceID = deviceID
    reindexCategoryOrder()

    var changedItems: [UUID] = []
    for index in state.items.indices where state.items[index].categoryID == id && state.items[index].deletedAt == nil {
      state.items[index].categoryID = Self.uncategorizedCategoryID
      state.items[index].updatedAt = now
      state.items[index].modifiedByDeviceID = deviceID
      changedItems.append(state.items[index].id)
    }

    rebuildOrder(in: Self.uncategorizedCategoryID, status: .active)
    rebuildOrder(in: Self.uncategorizedCategoryID, status: .completed)
    var changedReferences: Set<SyncRecordReference> = [
      SyncRecordReference(kind: .toDoCategory, id: id)
    ]
    for itemID in changedItems {
      changedReferences.insert(SyncRecordReference(kind: .toDoItem, id: itemID))
    }
    onRecordsChanged?(changedReferences)
  }

  func addItem(title: String, details: String, categoryID: UUID, coupleSpaceID: UUID? = nil) -> Bool {
    let normalizedTitle = normalizedNameFromInput(title)
    guard !normalizedTitle.isEmpty else { return false }

    let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
    let safeCategoryID = state.categories.contains(where: { $0.id == categoryID && $0.deletedAt == nil })
      ? categoryID : Self.uncategorizedCategoryID
    let nextOrder = (items(for: .active, in: safeCategoryID).map(\.order).max() ?? -1) + 1
    let now = Date()

    let item = ToDoItem(
      id: UUID(),
      coupleSpaceID: coupleSpaceID,
      title: normalizedTitle,
      details: normalizedDetails,
      categoryID: safeCategoryID,
      status: .active,
      order: nextOrder,
      createdAt: now,
      completedAt: nil,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: deviceID,
      version: Self.schemaVersion
    )
    state.items.append(item)
    notifyChanges([SyncRecordReference(kind: .toDoItem, id: item.id)])
    return true
  }

  func deleteItem(id: UUID) {
    guard let index = state.items.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
    let item = state.items[index]
    let now = Date()
    state.items[index].deletedAt = now
    state.items[index].updatedAt = now
    state.items[index].modifiedByDeviceID = deviceID
    rebuildOrder(in: item.categoryID, status: item.status)
    var touched = Set(bucketItemIDs(categoryID: item.categoryID, status: item.status, excluding: nil))
    touched.insert(id)
    notifyChanges(Set(touched.map { SyncRecordReference(kind: .toDoItem, id: $0) }))
  }

  func setCompleted(_ id: UUID, completed: Bool) {
    guard let item = state.items.first(where: { $0.id == id && $0.deletedAt == nil }) else { return }
    let targetStatus: ToDoStatus = completed ? .completed : .active
    moveItem(id: id, targetCategoryID: item.categoryID, targetStatus: targetStatus, before: nil)
    guard let index = state.items.firstIndex(where: { $0.id == id }) else { return }
    state.items[index].completedAt = completed ? Date() : nil
    touchItem(at: index)
    notifyChanges([SyncRecordReference(kind: .toDoItem, id: id)])
  }

  func moveItem(
    id: UUID,
    targetCategoryID: UUID,
    targetStatus: ToDoStatus,
    before targetItemID: UUID?
  ) {
    guard let dragged = state.items.first(where: { $0.id == id && $0.deletedAt == nil }) else { return }
    let safeCategoryID = state.categories.contains(where: { $0.id == targetCategoryID && $0.deletedAt == nil })
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
      targetIDs.insert(dragged.id, at: targetIDs.count)
    }

    if dragged.categoryID == safeCategoryID && dragged.status == targetStatus {
      applyOrder(itemIDs: targetIDs, categoryID: safeCategoryID, status: targetStatus)
    } else {
      applyOrder(itemIDs: sourceIDs, categoryID: dragged.categoryID, status: dragged.status)
      applyOrder(itemIDs: targetIDs, categoryID: safeCategoryID, status: targetStatus)
    }

    // A move re-orders every item in both the source and target buckets, so all
    // of them (not just the dragged item) must be synced.
    var touched = Set(sourceIDs)
    touched.formUnion(targetIDs)
    touched.insert(id)
    notifyChanges(Set(touched.map { SyncRecordReference(kind: .toDoItem, id: $0) }))
  }

  func assignCoupleSpaceID(_ coupleSpaceID: UUID) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = []

    for index in state.categories.indices where state.categories[index].deletedAt == nil {
      guard state.categories[index].coupleSpaceID != coupleSpaceID else { continue }
      state.categories[index].coupleSpaceID = coupleSpaceID
      touchCategory(at: index)
      references.insert(SyncRecordReference(kind: .toDoCategory, id: state.categories[index].id))
    }

    for index in state.items.indices where state.items[index].deletedAt == nil {
      guard state.items[index].coupleSpaceID != coupleSpaceID else { continue }
      state.items[index].coupleSpaceID = coupleSpaceID
      touchItem(at: index)
      references.insert(SyncRecordReference(kind: .toDoItem, id: state.items[index].id))
    }

    return references
  }

  func applyRemoteCategory(_ remote: ToDoCategory) -> Bool {
    if remote.deletedAt != nil {
      if let index = state.categories.firstIndex(where: { $0.id == remote.id }) {
        state.categories[index] = remote
      }
      return true
    }

    if let index = state.categories.firstIndex(where: { $0.id == remote.id }) {
      let local = state.categories[index]
      guard
        SyncMergeResolver.shouldApplyRemote(
          local: local,
          remote: remote,
          localUpdatedAt: local.updatedAt,
          remoteUpdatedAt: remote.updatedAt
        )
      else {
        return false
      }
      state.categories[index] = remote
      return true
    }

    state.categories.append(remote)
    reindexCategoryOrder()
    return true
  }

  func applyRemoteItem(_ remote: ToDoItem) -> Bool {
    if remote.deletedAt != nil {
      if let index = state.items.firstIndex(where: { $0.id == remote.id }) {
        state.items[index] = remote
      }
      return true
    }

    if let index = state.items.firstIndex(where: { $0.id == remote.id }) {
      let local = state.items[index]
      guard
        SyncMergeResolver.shouldApplyRemote(
          local: local,
          remote: remote,
          localUpdatedAt: local.updatedAt,
          remoteUpdatedAt: remote.updatedAt
        )
      else {
        return false
      }
      state.items[index] = remote
      return true
    }

    state.items.append(remote)
    return true
  }

  func categoryRecord(id: UUID) -> ToDoCategory? {
    state.categories.first(where: { $0.id == id })
  }

  func itemRecord(id: UUID) -> ToDoItem? {
    state.items.first(where: { $0.id == id })
  }

  func allSyncRecords(coupleSpaceID: UUID) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = []
    for category in state.categories where category.coupleSpaceID == coupleSpaceID {
      references.insert(SyncRecordReference(kind: .toDoCategory, id: category.id))
    }
    for item in state.items where item.coupleSpaceID == coupleSpaceID {
      references.insert(SyncRecordReference(kind: .toDoItem, id: item.id))
    }
    return references
  }

  private func save() {
    do {
      try fileManager.createDirectory(
        at: storeURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try encoder.encode(state)
      try data.write(to: storeURL, options: [.atomic])
    } catch {
      assertionFailure("Failed to save to-do store: \(error)")
    }
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
    let now = Date()
    for (index, itemID) in itemIDs.enumerated() {
      guard let itemIndex = state.items.firstIndex(where: { $0.id == itemID }) else { continue }
      state.items[itemIndex].categoryID = categoryID
      state.items[itemIndex].status = status
      state.items[itemIndex].order = index
      state.items[itemIndex].updatedAt = now
      state.items[itemIndex].modifiedByDeviceID = deviceID
    }
  }

  private func rebuildOrder(in categoryID: UUID, status: ToDoStatus) {
    let ids = bucketItemIDs(categoryID: categoryID, status: status, excluding: nil)
    applyOrder(itemIDs: ids, categoryID: categoryID, status: status)
  }

  private func reindexCategoryOrder() {
    let regularCategories = state.categories
      .filter { $0.id != Self.uncategorizedCategoryID && $0.deletedAt == nil }
      .sorted { lhs, rhs in lhs.order < rhs.order }

    var rebuilt: [ToDoCategory] = [
      Self.makeUncategorizedCategory(existing: state.categories.first(where: { $0.id == Self.uncategorizedCategoryID }))
    ]

    rebuilt += regularCategories.enumerated().map { index, category in
      var mutable = category
      mutable.order = index + 1
      return mutable
    }

    state.categories = rebuilt + state.categories.filter { $0.deletedAt != nil }
  }

  private func touchCategory(at index: Int) {
    state.categories[index].updatedAt = Date()
    state.categories[index].modifiedByDeviceID = deviceID
    state.categories[index].version = Self.schemaVersion
  }

  private func touchItem(at index: Int) {
    state.items[index].updatedAt = Date()
    state.items[index].modifiedByDeviceID = deviceID
    state.items[index].version = Self.schemaVersion
  }

  private func notifyChanges(_ references: Set<SyncRecordReference>) {
    guard !references.isEmpty else { return }
    onRecordsChanged?(references)
  }

  private func normalizedNameFromInput(_ input: String) -> String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func hasDuplicateCategoryName(_ name: String, excluding id: UUID? = nil) -> Bool {
    categories.contains { category in
      guard category.id != id else { return false }
      return category.name.caseInsensitiveCompare(name) == .orderedSame
    }
  }

  nonisolated private static func sortItems(_ lhs: ToDoItem, _ rhs: ToDoItem) -> Bool {
    if lhs.order != rhs.order { return lhs.order < rhs.order }
    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  private static func makeUncategorizedCategory(existing: ToDoCategory?) -> ToDoCategory {
    if var existing {
      existing.name = "Uncategorized"
      existing.order = 0
      existing.deletedAt = nil
      return existing
    }

    let now = Date()
    return ToDoCategory(
      id: uncategorizedCategoryID,
      coupleSpaceID: nil,
      name: "Uncategorized",
      order: 0,
      createdAt: now,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: AppDeviceIdentifier.current(),
      version: schemaVersion
    )
  }

  private static func defaultState(deviceID: String) -> ToDoPersistedState {
    let now = Date()
    return ToDoPersistedState(
      categories: [
        ToDoCategory(
          id: uncategorizedCategoryID,
          coupleSpaceID: nil,
          name: "Uncategorized",
          order: 0,
          createdAt: now,
          updatedAt: now,
          deletedAt: nil,
          modifiedByDeviceID: deviceID,
          version: schemaVersion
        )
      ],
      items: []
    )
  }

  private static func loadLegacyState(from userDefaults: UserDefaults) -> ToDoPersistedState? {
    guard
      let raw = userDefaults.string(forKey: legacyAppStorageKey),
      let data = raw.data(using: .utf8),
      let decoded = try? JSONDecoder().decode(LegacyToDoPersistedState.self, from: data)
    else {
      return nil
    }

    let now = Date()
    let deviceID = AppDeviceIdentifier.current()
    let categories = decoded.categories.map { category in
      ToDoCategory(
        id: category.id,
        coupleSpaceID: nil,
        name: category.name,
        order: category.order,
        createdAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: deviceID,
        version: schemaVersion
      )
    }

    let items = decoded.items.map { item in
      ToDoItem(
        id: item.id,
        coupleSpaceID: nil,
        title: item.title,
        details: item.details,
        categoryID: item.categoryID,
        status: item.status,
        order: item.order,
        createdAt: item.createdAt,
        completedAt: item.completedAt,
        updatedAt: item.completedAt ?? item.createdAt,
        deletedAt: nil,
        modifiedByDeviceID: deviceID,
        version: schemaVersion
      )
    }

    return ToDoPersistedState(categories: categories, items: items)
  }

  private static func normalize(_ state: ToDoPersistedState, deviceID: String) -> ToDoPersistedState {
    var categories = state.categories
    if !categories.contains(where: { $0.id == uncategorizedCategoryID }) {
      categories.append(makeUncategorizedCategory(existing: nil))
    }

    let regularCategories = categories
      .filter { $0.id != uncategorizedCategoryID && $0.deletedAt == nil }
      .sorted { lhs, rhs in lhs.order < rhs.order }
      .enumerated()
      .map { index, category in
        var mutable = category
        mutable.name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        mutable.order = index + 1
        mutable.version = max(mutable.version, schemaVersion)
        if mutable.modifiedByDeviceID.isEmpty {
          mutable.modifiedByDeviceID = deviceID
        }
        return mutable
      }

    let normalizedCategories: [ToDoCategory] = [
      makeUncategorizedCategory(existing: categories.first(where: { $0.id == uncategorizedCategoryID }))
    ] + regularCategories + categories.filter { $0.deletedAt != nil }

    let categoryIDs = Set(normalizedCategories.filter { $0.deletedAt == nil }.map(\.id))
    var normalizedItems = state.items.map { item in
      var mutable = item
      if !categoryIDs.contains(item.categoryID) {
        mutable.categoryID = uncategorizedCategoryID
      }
      mutable.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
      mutable.version = max(mutable.version, schemaVersion)
      if mutable.modifiedByDeviceID.isEmpty {
        mutable.modifiedByDeviceID = deviceID
      }
      return mutable
    }

    for category in normalizedCategories where category.deletedAt == nil {
      normalizedItems = normalizedItems.reorderedItems(in: category.id, status: .active)
      normalizedItems = normalizedItems.reorderedItems(in: category.id, status: .completed)
    }

    return ToDoPersistedState(categories: normalizedCategories, items: normalizedItems)
  }

  private static func defaultApplicationSupportDirectory(fileManager: FileManager) -> URL {
    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return baseURL.appendingPathComponent("Dear Diary", isDirectory: true)
  }
}

private struct LegacyToDoCategory: Codable {
  var id: UUID
  var name: String
  var order: Int
}

private struct LegacyToDoItem: Codable {
  var id: UUID
  var title: String
  var details: String
  var categoryID: UUID
  var status: ToDoStatus
  var order: Int
  var createdAt: Date
  var completedAt: Date?
}

private struct LegacyToDoPersistedState: Codable {
  var categories: [LegacyToDoCategory]
  var items: [LegacyToDoItem]
}

private extension Array where Element == ToDoItem {
  func reorderedItems(in categoryID: UUID, status: ToDoStatus) -> [ToDoItem] {
    var output = self
    let bucket = self
      .filter { $0.categoryID == categoryID && $0.status == status && $0.deletedAt == nil }
      .sorted { $0.order < $1.order }

    for (index, item) in bucket.enumerated() {
      guard let outputIndex = output.firstIndex(where: { $0.id == item.id }) else { continue }
      output[outputIndex].order = index
    }
    return output
  }
}
