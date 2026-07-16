@testable import Dear_Diary
import Foundation
import Testing

@MainActor
struct MilestoneStoreTests {
  @Test func addMilestonePersistsAndReloads() throws {
    let fixture = try MilestoneStoreFixture()
    let store = MilestoneStore(storeURL: fixture.storeURL, deviceID: "test-device")
    let anchorDate = Date(timeIntervalSince1970: 1800)

    let id = store.addMilestone(
      title: " First date ",
      date: anchorDate,
      note: " Dinner and a walk ",
      recurrence: .yearly,
      icon: "heart.fill"
    )

    #expect(id != nil)
    #expect(store.milestones.count == 1)
    #expect(store.milestones[0].title == "First date")
    #expect(store.milestones[0].note == "Dinner and a walk")
    #expect(store.milestones[0].recurrence == .yearly)
    #expect(store.milestones[0].modifiedByDeviceID == "test-device")

    let reloaded = MilestoneStore(storeURL: fixture.storeURL, deviceID: "test-device")
    #expect(reloaded.milestones.count == 1)
    #expect(reloaded.milestones[0].id == id)
  }

  @Test func addMilestoneTrimsTitleAndRejectsEmpty() throws {
    let fixture = try MilestoneStoreFixture()
    let store = MilestoneStore(storeURL: fixture.storeURL, deviceID: "test-device")

    let id = store.addMilestone(
      title: "   ",
      date: Date(),
      note: "",
      recurrence: .none,
      icon: "star.fill"
    )
    #expect(id == nil)
    #expect(store.milestones.isEmpty)
  }

  @Test func updateMutatesFieldsAndBumpsTimestamp() throws {
    let fixture = try MilestoneStoreFixture()
    let store = MilestoneStore(storeURL: fixture.storeURL, deviceID: "device-a")
    let id = try #require(store.addMilestone(
      title: "Anniversary",
      date: Date(timeIntervalSince1970: 1000),
      note: "Original note",
      recurrence: .none,
      icon: "star.fill"
    ))
    let original = try #require(store.milestoneRecord(id: id))

    let newDate = Date(timeIntervalSince1970: 5000)
    let updated = store.updateMilestone(
      id: id,
      title: "Anniversary (updated)",
      date: newDate,
      note: "New note",
      recurrence: .yearly,
      icon: "gift.fill"
    )

    #expect(updated)
    let record = try #require(store.milestoneRecord(id: id))
    #expect(record.title == "Anniversary (updated)")
    #expect(record.date == newDate)
    #expect(record.note == "New note")
    #expect(record.recurrence == .yearly)
    #expect(record.icon == "gift.fill")
    #expect(record.updatedAt > original.updatedAt)
    #expect(record.modifiedByDeviceID == "device-a")
  }

  @Test func softDeleteTombstonesMilestone() throws {
    let fixture = try MilestoneStoreFixture()
    let store = MilestoneStore(storeURL: fixture.storeURL, deviceID: "test-device")
    let id = try #require(store.addMilestone(
      title: "Milestone",
      date: Date(),
      note: "",
      recurrence: .none,
      icon: "star.fill"
    ))

    #expect(store.softDeleteMilestone(id: id))
    #expect(store.milestones.isEmpty)
    #expect(store.milestoneRecord(id: id)?.deletedAt != nil)
  }

  @Test func nextOccurrenceForOneTimeReturnsAnchorDate() throws {
    let fixture = try MilestoneStoreFixture()
    let store = MilestoneStore(storeURL: fixture.storeURL, deviceID: "test-device")
    let anchorDate = Date(timeIntervalSince1970: 123_456)
    let id = try #require(store.addMilestone(
      title: "One time",
      date: anchorDate,
      note: "",
      recurrence: .none,
      icon: "star.fill"
    ))
    let milestone = try #require(store.milestoneRecord(id: id))

    #expect(store.nextOccurrence(of: milestone, from: Date()) == anchorDate)
  }

  @Test func nextOccurrenceForYearlyRollsToThisYearWhenUpcoming() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let anchorDate = calendar.date(from: DateComponents(year: 2020, month: 8, day: 15))!
    let milestone = Milestone(
      id: UUID(),
      coupleSpaceID: nil,
      title: "Yearly",
      date: anchorDate,
      note: "",
      recurrence: .yearly,
      icon: "star.fill",
      linkedDiaryEntryID: nil,
      createdAt: Date(),
      updatedAt: Date(),
      deletedAt: nil,
      modifiedByDeviceID: "device",
      version: 1
    )
    let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))!

    let next = Milestone.nextOccurrence(of: milestone, from: referenceDate, calendar: calendar)
    let expected = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
    #expect(next == expected)
  }

  @Test func nextOccurrenceForYearlyRollsToNextYearWhenPassed() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let anchorDate = calendar.date(from: DateComponents(year: 2020, month: 3, day: 1))!
    let milestone = Milestone(
      id: UUID(),
      coupleSpaceID: nil,
      title: "Yearly",
      date: anchorDate,
      note: "",
      recurrence: .yearly,
      icon: "star.fill",
      linkedDiaryEntryID: nil,
      createdAt: Date(),
      updatedAt: Date(),
      deletedAt: nil,
      modifiedByDeviceID: "device",
      version: 1
    )
    let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))!

    let next = Milestone.nextOccurrence(of: milestone, from: referenceDate, calendar: calendar)
    let expected = calendar.date(from: DateComponents(year: 2027, month: 3, day: 1))!
    #expect(next == expected)
  }

  @Test func nextOccurrenceHandlesFeb29InNonLeapYear() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let anchorDate = calendar.date(from: DateComponents(year: 2020, month: 2, day: 29))!
    let milestone = Milestone(
      id: UUID(),
      coupleSpaceID: nil,
      title: "Leap day",
      date: anchorDate,
      note: "",
      recurrence: .yearly,
      icon: "star.fill",
      linkedDiaryEntryID: nil,
      createdAt: Date(),
      updatedAt: Date(),
      deletedAt: nil,
      modifiedByDeviceID: "device",
      version: 1
    )
    // 2026 is not a leap year, and Jan 1 2026 is before Feb 29, so the
    // occurrence should fall on Feb 28, 2026.
    let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    let next = Milestone.nextOccurrence(of: milestone, from: referenceDate, calendar: calendar)
    let expected = calendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!
    #expect(next == expected)
  }

  @Test func assignCoupleSpaceIDStampsIDAndReturnsReferences() throws {
    let fixture = try MilestoneStoreFixture()
    let store = MilestoneStore(storeURL: fixture.storeURL, deviceID: "test-device")
    let id = try #require(store.addMilestone(
      title: "Milestone",
      date: Date(),
      note: "",
      recurrence: .none,
      icon: "star.fill"
    ))

    let coupleSpaceID = UUID()
    let references = store.assignCoupleSpaceID(coupleSpaceID)

    #expect(references.contains(SyncRecordReference(kind: .milestone, id: id)))
    #expect(store.milestoneRecord(id: id)?.coupleSpaceID == coupleSpaceID)
  }
}

private struct MilestoneStoreFixture {
  let rootURL: URL
  let storeURL: URL

  init() throws {
    rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    storeURL = rootURL.appendingPathComponent("milestone.store.v1.json")
  }
}
