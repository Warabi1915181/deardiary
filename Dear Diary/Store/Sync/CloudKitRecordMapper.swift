import CloudKit
import Foundation

enum CloudKitRecordTypes {
  static let coupleSpace = "CoupleSpace"
  static let diaryEntry = "DiaryEntry"
  static let diaryPhoto = "DiaryPhoto"
  static let toDoCategory = "ToDoCategory"
  static let toDoItem = "ToDoItem"
  static let milestone = "Milestone"

  static let zoneName = "CoupleSpaceZone"
}

enum CloudKitField {
  static let datingStartDay = "datingStartDay"
  static let coupleSpaceID = "coupleSpaceID"
  static let title = "title"
  static let body = "body"
  static let entryDate = "entryDate"
  static let mood = "mood"
  static let tags = "tags"
  static let isFavorite = "isFavorite"
  static let diaryEntryID = "diaryEntryID"
  static let filename = "filename"
  static let asset = "asset"
  static let name = "name"
  static let order = "order"
  static let details = "details"
  static let categoryID = "categoryID"
  static let status = "status"
  static let completedAt = "completedAt"
  static let date = "date"
  static let recurrence = "recurrence"
  static let icon = "icon"
  static let linkedDiaryEntryID = "linkedDiaryEntryID"
  static let note = "note"
  static let createdAt = "createdAt"
  static let updatedAt = "updatedAt"
  static let deletedAt = "deletedAt"
  static let modifiedByDeviceID = "modifiedByDeviceID"
  static let version = "version"
}

enum CloudKitRecordMapper {
  static func zoneID(ownerName: String) -> CKRecordZone.ID {
    CKRecordZone.ID(zoneName: CloudKitRecordTypes.zoneName, ownerName: ownerName)
  }

  static func recordID(for reference: SyncRecordReference, zoneID: CKRecordZone.ID) -> CKRecord.ID {
    CKRecord.ID(recordName: recordName(for: reference), zoneID: zoneID)
  }

  static func recordName(for reference: SyncRecordReference) -> String {
    switch reference.kind {
    case .coupleSpace:
      return reference.id.uuidString
    case .diaryEntry:
      return "DiaryEntry-\(reference.id.uuidString)"
    case .diaryPhoto:
      return "DiaryPhoto-\(reference.id.uuidString)"
    case .toDoCategory:
      return "ToDoCategory-\(reference.id.uuidString)"
    case .toDoItem:
      return "ToDoItem-\(reference.id.uuidString)"
    case .milestone:
      return "Milestone-\(reference.id.uuidString)"
    }
  }

  static func reference(from recordID: CKRecord.ID) -> SyncRecordReference? {
    let name = recordID.recordName
    if let id = UUID(uuidString: name) {
      return SyncRecordReference(kind: .coupleSpace, id: id)
    }
    if name.hasPrefix("DiaryEntry-"), let id = UUID(uuidString: String(name.dropFirst("DiaryEntry-".count))) {
      return SyncRecordReference(kind: .diaryEntry, id: id)
    }
    if name.hasPrefix("DiaryPhoto-"), let id = UUID(uuidString: String(name.dropFirst("DiaryPhoto-".count))) {
      return SyncRecordReference(kind: .diaryPhoto, id: id)
    }
    if name.hasPrefix("ToDoCategory-"), let id = UUID(uuidString: String(name.dropFirst("ToDoCategory-".count))) {
      return SyncRecordReference(kind: .toDoCategory, id: id)
    }
    if name.hasPrefix("ToDoItem-"), let id = UUID(uuidString: String(name.dropFirst("ToDoItem-".count))) {
      return SyncRecordReference(kind: .toDoItem, id: id)
    }
    if name.hasPrefix("Milestone-"), let id = UUID(uuidString: String(name.dropFirst("Milestone-".count))) {
      return SyncRecordReference(kind: .milestone, id: id)
    }
    return nil
  }

  static func coupleSpaceRecord(
    from space: CoupleSpace,
    zoneID: CKRecordZone.ID,
    parent: CKRecord? = nil
  ) -> CKRecord {
    let recordID = CKRecord.ID(recordName: space.id.uuidString, zoneID: zoneID)
    let record = CKRecord(recordType: CloudKitRecordTypes.coupleSpace, recordID: recordID)
    record[CloudKitField.datingStartDay] = space.datingStartDay
    record[CloudKitField.createdAt] = space.createdAt
    record[CloudKitField.updatedAt] = space.updatedAt
    record[CloudKitField.deletedAt] = space.deletedAt
    record[CloudKitField.modifiedByDeviceID] = space.modifiedByDeviceID
    record[CloudKitField.version] = space.version
    if let parent {
      record.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
    }
    return record
  }

  static func coupleSpace(from record: CKRecord) -> CoupleSpace? {
    guard record.recordType == CloudKitRecordTypes.coupleSpace else { return nil }
    guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }
    guard let datingStartDay = record[CloudKitField.datingStartDay] as? Date else { return nil }

    return CoupleSpace(
      id: id,
      datingStartDay: datingStartDay,
      createdAt: record[CloudKitField.createdAt] as? Date ?? datingStartDay,
      updatedAt: record[CloudKitField.updatedAt] as? Date ?? datingStartDay,
      deletedAt: record[CloudKitField.deletedAt] as? Date,
      modifiedByDeviceID: record[CloudKitField.modifiedByDeviceID] as? String ?? "",
      version: record[CloudKitField.version] as? Int ?? 1
    )
  }

  static func diaryEntryRecord(
    from entry: DiaryEntry,
    zoneID: CKRecordZone.ID,
    parent: CKRecord
  ) -> CKRecord {
    let recordID = CKRecord.ID(recordName: recordName(for: SyncRecordReference(kind: .diaryEntry, id: entry.id)), zoneID: zoneID)
    let record = CKRecord(recordType: CloudKitRecordTypes.diaryEntry, recordID: recordID)
    record.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
    record[CloudKitField.coupleSpaceID] = entry.coupleSpaceID?.uuidString
    record[CloudKitField.title] = entry.title
    record[CloudKitField.body] = entry.body
    record[CloudKitField.entryDate] = entry.entryDate
    record[CloudKitField.mood] = entry.mood?.rawValue
    record[CloudKitField.tags] = entry.tags
    record[CloudKitField.isFavorite] = entry.isFavorite ? 1 : 0
    record[CloudKitField.createdAt] = entry.createdAt
    record[CloudKitField.updatedAt] = entry.updatedAt
    record[CloudKitField.deletedAt] = entry.deletedAt
    record[CloudKitField.modifiedByDeviceID] = entry.modifiedByDeviceID
    record[CloudKitField.version] = entry.version
    return record
  }

  static func diaryEntry(from record: CKRecord) -> DiaryEntry? {
    guard record.recordType == CloudKitRecordTypes.diaryEntry else { return nil }
    guard let reference = reference(from: record.recordID), reference.kind == .diaryEntry else { return nil }

    let moodRaw = record[CloudKitField.mood] as? String
    let coupleSpaceRaw = record[CloudKitField.coupleSpaceID] as? String

    return DiaryEntry(
      id: reference.id,
      coupleSpaceID: coupleSpaceRaw.flatMap(UUID.init(uuidString:)),
      title: record[CloudKitField.title] as? String ?? "",
      body: record[CloudKitField.body] as? String ?? "",
      entryDate: record[CloudKitField.entryDate] as? Date ?? Date(),
      mood: moodRaw.flatMap(DiaryMood.init(rawValue:)),
      tags: record[CloudKitField.tags] as? [String] ?? [],
      photos: [],
      isFavorite: (record[CloudKitField.isFavorite] as? Int ?? 0) == 1,
      createdAt: record[CloudKitField.createdAt] as? Date ?? Date(),
      updatedAt: record[CloudKitField.updatedAt] as? Date ?? Date(),
      deletedAt: record[CloudKitField.deletedAt] as? Date,
      modifiedByDeviceID: record[CloudKitField.modifiedByDeviceID] as? String ?? "",
      version: record[CloudKitField.version] as? Int ?? 1
    )
  }

  static func diaryPhotoRecord(
    from photo: DiaryPhoto,
    entryID: UUID,
    coupleSpaceID: UUID,
    zoneID: CKRecordZone.ID,
    parent: CKRecord,
    assetURL: URL?
  ) -> CKRecord {
    let recordID = CKRecord.ID(recordName: recordName(for: SyncRecordReference(kind: .diaryPhoto, id: photo.id)), zoneID: zoneID)
    let record = CKRecord(recordType: CloudKitRecordTypes.diaryPhoto, recordID: recordID)
    record.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
    record[CloudKitField.coupleSpaceID] = coupleSpaceID.uuidString
    record[CloudKitField.diaryEntryID] = entryID.uuidString
    record[CloudKitField.filename] = photo.filename
    record[CloudKitField.createdAt] = photo.createdAt
    record[CloudKitField.updatedAt] = photo.createdAt
    if let assetURL {
      record[CloudKitField.asset] = CKAsset(fileURL: assetURL)
    }
    return record
  }

  static func diaryPhoto(from record: CKRecord) -> DiaryPhoto? {
    guard record.recordType == CloudKitRecordTypes.diaryPhoto else { return nil }
    guard let reference = reference(from: record.recordID), reference.kind == .diaryPhoto else { return nil }

    return DiaryPhoto(
      id: reference.id,
      filename: record[CloudKitField.filename] as? String ?? "\(reference.id.uuidString).jpg",
      createdAt: record[CloudKitField.createdAt] as? Date ?? Date()
    )
  }

  static func diaryEntryID(from photoRecord: CKRecord) -> UUID? {
    guard let raw = photoRecord[CloudKitField.diaryEntryID] as? String else { return nil }
    return UUID(uuidString: raw)
  }

  static func toDoCategoryRecord(
    from category: ToDoCategory,
    zoneID: CKRecordZone.ID,
    parent: CKRecord
  ) -> CKRecord {
    let recordID = CKRecord.ID(recordName: recordName(for: SyncRecordReference(kind: .toDoCategory, id: category.id)), zoneID: zoneID)
    let record = CKRecord(recordType: CloudKitRecordTypes.toDoCategory, recordID: recordID)
    record.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
    record[CloudKitField.coupleSpaceID] = category.coupleSpaceID?.uuidString
    record[CloudKitField.name] = category.name
    record[CloudKitField.order] = category.order
    record[CloudKitField.createdAt] = category.createdAt
    record[CloudKitField.updatedAt] = category.updatedAt
    record[CloudKitField.deletedAt] = category.deletedAt
    record[CloudKitField.modifiedByDeviceID] = category.modifiedByDeviceID
    record[CloudKitField.version] = category.version
    return record
  }

  static func toDoCategory(from record: CKRecord) -> ToDoCategory? {
    guard record.recordType == CloudKitRecordTypes.toDoCategory else { return nil }
    guard let reference = reference(from: record.recordID), reference.kind == .toDoCategory else { return nil }

    let coupleSpaceRaw = record[CloudKitField.coupleSpaceID] as? String
    return ToDoCategory(
      id: reference.id,
      coupleSpaceID: coupleSpaceRaw.flatMap(UUID.init(uuidString:)),
      name: record[CloudKitField.name] as? String ?? "",
      order: record[CloudKitField.order] as? Int ?? 0,
      createdAt: record[CloudKitField.createdAt] as? Date ?? Date(),
      updatedAt: record[CloudKitField.updatedAt] as? Date ?? Date(),
      deletedAt: record[CloudKitField.deletedAt] as? Date,
      modifiedByDeviceID: record[CloudKitField.modifiedByDeviceID] as? String ?? "",
      version: record[CloudKitField.version] as? Int ?? 1
    )
  }

  static func toDoItemRecord(
    from item: ToDoItem,
    zoneID: CKRecordZone.ID,
    parent: CKRecord
  ) -> CKRecord {
    let recordID = CKRecord.ID(recordName: recordName(for: SyncRecordReference(kind: .toDoItem, id: item.id)), zoneID: zoneID)
    let record = CKRecord(recordType: CloudKitRecordTypes.toDoItem, recordID: recordID)
    record.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
    record[CloudKitField.coupleSpaceID] = item.coupleSpaceID?.uuidString
    record[CloudKitField.title] = item.title
    record[CloudKitField.details] = item.details
    record[CloudKitField.categoryID] = item.categoryID.uuidString
    record[CloudKitField.status] = item.status.rawValue
    record[CloudKitField.order] = item.order
    record[CloudKitField.createdAt] = item.createdAt
    record[CloudKitField.completedAt] = item.completedAt
    record[CloudKitField.updatedAt] = item.updatedAt
    record[CloudKitField.deletedAt] = item.deletedAt
    record[CloudKitField.modifiedByDeviceID] = item.modifiedByDeviceID
    record[CloudKitField.version] = item.version
    return record
  }

  static func toDoItem(from record: CKRecord) -> ToDoItem? {
    guard record.recordType == CloudKitRecordTypes.toDoItem else { return nil }
    guard let reference = reference(from: record.recordID), reference.kind == .toDoItem else { return nil }
    guard let categoryRaw = record[CloudKitField.categoryID] as? String, let categoryID = UUID(uuidString: categoryRaw) else {
      return nil
    }

    let statusRaw = record[CloudKitField.status] as? String ?? ToDoStatus.active.rawValue
    let coupleSpaceRaw = record[CloudKitField.coupleSpaceID] as? String

    return ToDoItem(
      id: reference.id,
      coupleSpaceID: coupleSpaceRaw.flatMap(UUID.init(uuidString:)),
      title: record[CloudKitField.title] as? String ?? "",
      details: record[CloudKitField.details] as? String ?? "",
      categoryID: categoryID,
      status: ToDoStatus(rawValue: statusRaw) ?? .active,
      order: record[CloudKitField.order] as? Int ?? 0,
      createdAt: record[CloudKitField.createdAt] as? Date ?? Date(),
      completedAt: record[CloudKitField.completedAt] as? Date,
      updatedAt: record[CloudKitField.updatedAt] as? Date ?? Date(),
      deletedAt: record[CloudKitField.deletedAt] as? Date,
      modifiedByDeviceID: record[CloudKitField.modifiedByDeviceID] as? String ?? "",
      version: record[CloudKitField.version] as? Int ?? 1
    )
  }

  static func milestoneRecord(
    from milestone: Milestone,
    zoneID: CKRecordZone.ID,
    parent: CKRecord
  ) -> CKRecord {
    let recordID = CKRecord.ID(recordName: recordName(for: SyncRecordReference(kind: .milestone, id: milestone.id)), zoneID: zoneID)
    let record = CKRecord(recordType: CloudKitRecordTypes.milestone, recordID: recordID)
    record.parent = CKRecord.Reference(recordID: parent.recordID, action: .none)
    record[CloudKitField.coupleSpaceID] = milestone.coupleSpaceID?.uuidString
    record[CloudKitField.title] = milestone.title
    record[CloudKitField.note] = milestone.note
    record[CloudKitField.date] = milestone.date
    record[CloudKitField.recurrence] = milestone.recurrence.rawValue
    record[CloudKitField.icon] = milestone.icon
    record[CloudKitField.linkedDiaryEntryID] = milestone.linkedDiaryEntryID?.uuidString
    record[CloudKitField.createdAt] = milestone.createdAt
    record[CloudKitField.updatedAt] = milestone.updatedAt
    record[CloudKitField.deletedAt] = milestone.deletedAt
    record[CloudKitField.modifiedByDeviceID] = milestone.modifiedByDeviceID
    record[CloudKitField.version] = milestone.version
    return record
  }

  static func milestone(from record: CKRecord) -> Milestone? {
    guard record.recordType == CloudKitRecordTypes.milestone else { return nil }
    guard let reference = reference(from: record.recordID), reference.kind == .milestone else { return nil }

    let recurrenceRaw = record[CloudKitField.recurrence] as? String ?? MilestoneRecurrence.none.rawValue
    let coupleSpaceRaw = record[CloudKitField.coupleSpaceID] as? String
    let linkedDiaryEntryRaw = record[CloudKitField.linkedDiaryEntryID] as? String

    return Milestone(
      id: reference.id,
      coupleSpaceID: coupleSpaceRaw.flatMap(UUID.init(uuidString:)),
      title: record[CloudKitField.title] as? String ?? "",
      date: record[CloudKitField.date] as? Date ?? Date(),
      note: record[CloudKitField.note] as? String ?? "",
      recurrence: MilestoneRecurrence(rawValue: recurrenceRaw) ?? .none,
      icon: record[CloudKitField.icon] as? String ?? "",
      linkedDiaryEntryID: linkedDiaryEntryRaw.flatMap(UUID.init(uuidString:)),
      createdAt: record[CloudKitField.createdAt] as? Date ?? Date(),
      updatedAt: record[CloudKitField.updatedAt] as? Date ?? Date(),
      deletedAt: record[CloudKitField.deletedAt] as? Date,
      modifiedByDeviceID: record[CloudKitField.modifiedByDeviceID] as? String ?? "",
      version: record[CloudKitField.version] as? Int ?? 1
    )
  }
}
