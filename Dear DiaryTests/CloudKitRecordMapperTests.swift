import CloudKit
@testable import Dear_Diary
import Foundation
import Testing

struct CloudKitRecordMapperTests {
  @Test func coupleSpaceRoundTrip() {
    let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let datingStartDay = Date(timeIntervalSince1970: 1_700_000_000)
    let space = CoupleSpace(
      id: id,
      datingStartDay: datingStartDay,
      createdAt: datingStartDay,
      updatedAt: datingStartDay,
      deletedAt: nil,
      modifiedByDeviceID: "device-a",
      version: 1
    )
    let zoneID = CloudKitRecordMapper.zoneID(ownerName: CKCurrentUserDefaultName)
    let record = CloudKitRecordMapper.coupleSpaceRecord(from: space, zoneID: zoneID)
    let decoded = CloudKitRecordMapper.coupleSpace(from: record)

    #expect(decoded?.id == id)
    #expect(decoded?.datingStartDay == datingStartDay)
    #expect(decoded?.modifiedByDeviceID == "device-a")
  }

  @Test func diaryEntryRoundTrip() {
    let spaceID = UUID()
    let entryID = UUID()
    let entryDate = Date(timeIntervalSince1970: 1_800_000_000)
    let entry = DiaryEntry(
      id: entryID,
      coupleSpaceID: spaceID,
      title: "Rainy day",
      body: "Tea and books",
      entryDate: entryDate,
      mood: .cozy,
      tags: ["home"],
      photos: [],
      isFavorite: true,
      createdAt: entryDate,
      updatedAt: entryDate,
      deletedAt: nil,
      modifiedByDeviceID: "device-a",
      version: 1
    )

    let zoneID = CloudKitRecordMapper.zoneID(ownerName: CKCurrentUserDefaultName)
    let root = CloudKitRecordMapper.coupleSpaceRecord(
      from: CoupleSpace(
        id: spaceID,
        datingStartDay: entryDate,
        createdAt: entryDate,
        updatedAt: entryDate,
        deletedAt: nil,
        modifiedByDeviceID: "device-a",
        version: 1
      ),
      zoneID: zoneID
    )
    let record = CloudKitRecordMapper.diaryEntryRecord(from: entry, zoneID: zoneID, parent: root)
    let decoded = CloudKitRecordMapper.diaryEntry(from: record)

    #expect(decoded?.id == entryID)
    #expect(decoded?.title == "Rainy day")
    #expect(decoded?.mood == .cozy)
    #expect(decoded?.tags == ["home"])
    #expect(decoded?.isFavorite == true)
  }

  @Test func toDoItemRoundTrip() {
    let spaceID = UUID()
    let categoryID = UUID()
    let itemID = UUID()
    let now = Date(timeIntervalSince1970: 1_900_000_000)
    let item = ToDoItem(
      id: itemID,
      coupleSpaceID: spaceID,
      title: "Weekend picnic",
      details: "Bring blanket",
      categoryID: categoryID,
      status: .active,
      order: 2,
      createdAt: now,
      completedAt: nil,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: "device-a",
      version: 1
    )

    let zoneID = CloudKitRecordMapper.zoneID(ownerName: CKCurrentUserDefaultName)
    let root = CloudKitRecordMapper.coupleSpaceRecord(
      from: CoupleSpace(
        id: spaceID,
        datingStartDay: now,
        createdAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "device-a",
        version: 1
      ),
      zoneID: zoneID
    )
    let record = CloudKitRecordMapper.toDoItemRecord(from: item, zoneID: zoneID, parent: root)
    let decoded = CloudKitRecordMapper.toDoItem(from: record)

    #expect(decoded?.id == itemID)
    #expect(decoded?.title == "Weekend picnic")
    #expect(decoded?.order == 2)
    #expect(decoded?.categoryID == categoryID)
  }
}
