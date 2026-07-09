import Foundation
import Testing
@testable import Dear_Diary

@MainActor
struct CoupleSpaceStoreTests {
  @Test func migratesLegacyDatingStartDay() throws {
    let fixture = try StoreFixture()
    let legacyDate = Date(timeIntervalSince1970: 1_600_000_000)
    fixture.userDefaults.set(legacyDate.timeIntervalSince1970, forKey: CoupleSpaceStore.legacyDatingStartDayKey)

    let store = CoupleSpaceStore(
      storeURL: fixture.coupleSpaceURL,
      userDefaults: fixture.userDefaults,
      deviceID: "test-device"
    )

    #expect(store.coupleSpace != nil)
    #expect(store.datingStartDay == DatingStartDayStore.clamp(legacyDate))
  }

  @Test func latestRemoteCoupleSpaceWins() throws {
    let fixture = try StoreFixture()
    let store = CoupleSpaceStore(
      storeURL: fixture.coupleSpaceURL,
      userDefaults: fixture.userDefaults,
      deviceID: "test-device"
    )
    let local = store.ensureCoupleSpace()

    let remote = CoupleSpace(
      id: local.id,
      datingStartDay: Date(timeIntervalSince1970: 1_700_000_000),
      createdAt: local.createdAt,
      updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
      deletedAt: nil,
      modifiedByDeviceID: "partner-device",
      version: 1
    )

    #expect(store.applyRemoteCoupleSpace(remote))
    #expect(store.datingStartDay == remote.datingStartDay)
  }
}

@MainActor
struct ToDoStoreSyncTests {
  @Test func migratesLegacyUserDefaultsState() throws {
    let fixture = try StoreFixture()
    let legacy = LegacyToDoPersistedState(
      categories: [
        LegacyToDoCategory(id: ToDoStore.uncategorizedCategoryID, name: "Uncategorized", order: 0),
        LegacyToDoCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Dates", order: 1),
      ],
      items: [
        LegacyToDoItem(
          id: UUID(),
          title: "Picnic",
          details: "",
          categoryID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          status: .active,
          order: 0,
          createdAt: Date(timeIntervalSince1970: 1_000),
          completedAt: nil
        )
      ]
    )
    let data = try JSONEncoder().encode(legacy)
    fixture.userDefaults.set(String(data: data, encoding: .utf8), forKey: ToDoStore.legacyAppStorageKey)

    let store = ToDoStore(
      storeURL: fixture.todoURL,
      userDefaults: fixture.userDefaults,
      deviceID: "test-device"
    )

    #expect(store.categories.count == 2)
    #expect(store.items(for: .active, in: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!).count == 1)
    #expect(fixture.userDefaults.string(forKey: ToDoStore.legacyAppStorageKey) == nil)
  }

  @Test func softDeleteHidesCategoryAndItems() throws {
    let fixture = try StoreFixture()
    let store = ToDoStore(
      storeURL: fixture.todoURL,
      userDefaults: fixture.userDefaults,
      deviceID: "test-device"
    )
    #expect(store.addCategory(name: "Trips"))
    let categoryID = store.categories.first(where: { $0.name == "Trips" })!.id
    #expect(store.addItem(title: "Kyoto", details: "", categoryID: categoryID))

    store.deleteCategory(id: categoryID)

    #expect(store.categories.contains(where: { $0.id == categoryID }) == false)
    #expect(store.items(for: .active, in: ToDoStore.uncategorizedCategoryID).contains(where: { $0.title == "Kyoto" }))
    #expect(store.categoryRecord(id: categoryID)?.deletedAt != nil)
  }

  @Test func latestRemoteToDoItemWins() throws {
    let fixture = try StoreFixture()
    let itemID = UUID()
    let localUpdatedAt = Date(timeIntervalSince1970: 1_000)
    let previewState = ToDoPersistedState(
      categories: [
        ToDoCategory(
          id: ToDoStore.uncategorizedCategoryID,
          coupleSpaceID: nil,
          name: "Uncategorized",
          order: 0,
          createdAt: localUpdatedAt,
          updatedAt: localUpdatedAt,
          deletedAt: nil,
          modifiedByDeviceID: "test-device",
          version: 1
        )
      ],
      items: [
        ToDoItem(
          id: itemID,
          coupleSpaceID: nil,
          title: "Old title",
          details: "",
          categoryID: ToDoStore.uncategorizedCategoryID,
          status: .active,
          order: 0,
          createdAt: localUpdatedAt,
          completedAt: nil,
          updatedAt: localUpdatedAt,
          deletedAt: nil,
          modifiedByDeviceID: "test-device",
          version: 1
        )
      ]
    )
    let store = ToDoStore(
      storeURL: fixture.todoURL,
      userDefaults: fixture.userDefaults,
      deviceID: "test-device",
      previewState: previewState
    )

    let remote = ToDoItem(
      id: itemID,
      coupleSpaceID: UUID(),
      title: "New title",
      details: "From partner",
      categoryID: ToDoStore.uncategorizedCategoryID,
      status: .active,
      order: 0,
      createdAt: localUpdatedAt,
      completedAt: nil,
      updatedAt: Date(timeIntervalSince1970: 2_000),
      deletedAt: nil,
      modifiedByDeviceID: "partner-device",
      version: 1
    )

    #expect(store.applyRemoteItem(remote))
    #expect(store.itemRecord(id: itemID)?.title == "New title")
  }

  @Test func assignCoupleSpaceIDMarksRecordsForSync() throws {
    let fixture = try StoreFixture()
    let store = ToDoStore(
      storeURL: fixture.todoURL,
      userDefaults: fixture.userDefaults,
      deviceID: "test-device"
    )
    #expect(store.addCategory(name: "Food"))
    #expect(store.addItem(title: "Sushi", details: "", categoryID: store.categories[1].id))

    let coupleSpaceID = UUID()
    let references = store.assignCoupleSpaceID(coupleSpaceID)

    #expect(!references.isEmpty)
    #expect(store.state.categories.allSatisfy { $0.coupleSpaceID == coupleSpaceID || $0.deletedAt != nil })
    #expect(store.state.items.allSatisfy { $0.coupleSpaceID == coupleSpaceID || $0.deletedAt != nil })
  }
}

private struct StoreFixture {
  let rootURL: URL
  let coupleSpaceURL: URL
  let todoURL: URL
  let userDefaults: UserDefaults

  init() throws {
    rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    coupleSpaceURL = rootURL.appendingPathComponent("coupleSpace.store.v1.json")
    todoURL = rootURL.appendingPathComponent("todo.store.v1.json")
    userDefaults = UserDefaults(suiteName: UUID().uuidString)!
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
