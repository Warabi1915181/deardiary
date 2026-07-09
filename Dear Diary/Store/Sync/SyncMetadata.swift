import Foundation

enum SyncRecordKind: String, Codable, Hashable {
  case coupleSpace
  case diaryEntry
  case diaryPhoto
  case toDoCategory
  case toDoItem
}

struct SyncRecordReference: Hashable, Codable {
  var kind: SyncRecordKind
  var id: UUID
}

enum SyncConnectionRole: String, Codable {
  case owner
  case participant
}

struct SyncConnection: Codable, Hashable {
  var role: SyncConnectionRole
  var zoneName: String
  var zoneOwnerName: String
  var shareRecordName: String?
  var partnerDisplayName: String?
  var isActive: Bool
}

enum AppDeviceIdentifier {
  private static let key = "dearDiary.deviceID"

  static func current(userDefaults: UserDefaults = .standard) -> String {
    if let existing = userDefaults.string(forKey: key) {
      return existing
    }

    let generated = UUID().uuidString
    userDefaults.set(generated, forKey: key)
    return generated
  }
}

protocol SyncStamped {
  var updatedAt: Date { get set }
  var deletedAt: Date? { get set }
  var modifiedByDeviceID: String { get set }
  var version: Int { get set }
}

enum SyncMergeResolver {
  static func shouldApplyRemote<T>(
    local: T?,
    remote: T,
    localUpdatedAt: Date?,
    remoteUpdatedAt: Date
  ) -> Bool where T: SyncStamped {
    guard let local else { return true }
    if localUpdatedAt == nil { return true }
    if remoteUpdatedAt > local.updatedAt { return true }
    if remoteUpdatedAt < local.updatedAt { return false }
    return remote.modifiedByDeviceID != local.modifiedByDeviceID
  }
}
