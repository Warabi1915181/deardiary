import Combine
import Foundation

struct CoupleSpace: Identifiable, Codable, Hashable, SyncStamped {
  var id: UUID
  var datingStartDay: Date
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?
  var modifiedByDeviceID: String
  var version: Int
}

struct CoupleSpacePersistedState: Codable {
  var coupleSpace: CoupleSpace?
  var syncConnection: SyncConnection?
  var pendingPartnerMergePrompt: Bool
}

final class CoupleSpaceStore: ObservableObject {
  static let schemaVersion = 1
  static let legacyDatingStartDayKey = DatingStartDayStore.appStorageKey

  @Published private(set) var state: CoupleSpacePersistedState {
    didSet { save() }
  }

  private let storeURL: URL
  private let userDefaults: UserDefaults
  private let deviceID: String
  private let fileManager: FileManager
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  var onRecordsChanged: ((Set<SyncRecordReference>) -> Void)?

  init(
    storeURL: URL? = nil,
    userDefaults: UserDefaults = .standard,
    deviceID: String = AppDeviceIdentifier.current(),
    fileManager: FileManager = .default
  ) {
    self.userDefaults = userDefaults
    self.deviceID = deviceID
    self.fileManager = fileManager

    let baseURL = storeURL?.deletingLastPathComponent()
      ?? Self.defaultApplicationSupportDirectory(fileManager: fileManager)
    self.storeURL = storeURL ?? baseURL.appendingPathComponent("coupleSpace.store.v1.json")

    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    if
      let data = try? Data(contentsOf: self.storeURL),
      let decoded = try? decoder.decode(CoupleSpacePersistedState.self, from: data)
    {
      self.state = Self.normalize(decoded)
    } else {
      let datingStartDay = Self.legacyDatingStartDay(from: userDefaults)
      self.state = CoupleSpacePersistedState(
        coupleSpace: nil,
        syncConnection: nil,
        pendingPartnerMergePrompt: false
      )
      if let datingStartDay {
        _ = createLocalCoupleSpace(datingStartDay: datingStartDay)
      } else {
        save()
      }
    }
  }

  var coupleSpace: CoupleSpace? {
    guard state.coupleSpace?.deletedAt == nil else { return nil }
    return state.coupleSpace
  }

  var syncConnection: SyncConnection? {
    guard state.syncConnection?.isActive == true else { return nil }
    return state.syncConnection
  }

  var isSynced: Bool {
    syncConnection != nil
  }

  var datingStartDay: Date {
    coupleSpace?.datingStartDay
      ?? Self.legacyDatingStartDay(from: userDefaults)
      ?? DatingStartDayStore.clamp(Date())
  }

  var pendingPartnerMergePrompt: Bool {
    state.pendingPartnerMergePrompt
  }

  @discardableResult
  func createLocalCoupleSpace(datingStartDay: Date) -> CoupleSpace {
    let now = Date()
    let space = CoupleSpace(
      id: UUID(),
      datingStartDay: DatingStartDayStore.clamp(datingStartDay),
      createdAt: now,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: deviceID,
      version: Self.schemaVersion
    )
    state.coupleSpace = space
    notifyChange(.coupleSpace, id: space.id)
    return space
  }

  func ensureCoupleSpace() -> CoupleSpace {
    if let coupleSpace {
      return coupleSpace
    }
    return createLocalCoupleSpace(datingStartDay: datingStartDay)
  }

  func setDatingStartDay(_ date: Date) -> Bool {
    var space = ensureCoupleSpace()
    let clamped = DatingStartDayStore.clamp(date)
    guard space.datingStartDay != clamped else { return false }

    space.datingStartDay = clamped
    stamp(&space)
    state.coupleSpace = space
    userDefaults.set(clamped.timeIntervalSince1970, forKey: Self.legacyDatingStartDayKey)
    notifyChange(.coupleSpace, id: space.id)
    return true
  }

  func setSyncConnection(_ connection: SyncConnection?) {
    state.syncConnection = connection
  }

  func setPendingPartnerMergePrompt(_ pending: Bool) {
    state.pendingPartnerMergePrompt = pending
  }

  func applyRemoteCoupleSpace(_ remote: CoupleSpace) -> Bool {
    guard remote.deletedAt == nil else {
      if state.coupleSpace?.id == remote.id {
        state.coupleSpace = remote
      }
      return true
    }

    guard
      SyncMergeResolver.shouldApplyRemote(
        local: state.coupleSpace,
        remote: remote,
        localUpdatedAt: state.coupleSpace?.updatedAt,
        remoteUpdatedAt: remote.updatedAt
      )
    else {
      return false
    }

    state.coupleSpace = remote
    userDefaults.set(remote.datingStartDay.timeIntervalSince1970, forKey: Self.legacyDatingStartDayKey)
    return true
  }

  func leaveSharedDiary() {
    state.syncConnection = nil
    state.pendingPartnerMergePrompt = false
  }

  func assignCoupleSpaceID(_ coupleSpaceID: UUID) {
    guard var space = state.coupleSpace, space.id != coupleSpaceID else { return }
    space.id = coupleSpaceID
    stamp(&space)
    state.coupleSpace = space
    notifyChange(.coupleSpace, id: space.id)
  }

  private func stamp(_ space: inout CoupleSpace) {
    space.updatedAt = Date()
    space.modifiedByDeviceID = deviceID
    space.version = Self.schemaVersion
  }

  private func notifyChange(_ kind: SyncRecordKind, id: UUID) {
    onRecordsChanged?([SyncRecordReference(kind: kind, id: id)])
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
      assertionFailure("Failed to save couple space store: \(error)")
    }
  }

  private static func normalize(_ state: CoupleSpacePersistedState) -> CoupleSpacePersistedState {
    var normalized = state
    if var space = normalized.coupleSpace {
      space.datingStartDay = DatingStartDayStore.clamp(space.datingStartDay)
      space.version = max(space.version, schemaVersion)
      normalized.coupleSpace = space
    }
    return normalized
  }

  private static func legacyDatingStartDay(from userDefaults: UserDefaults) -> Date? {
    let interval = userDefaults.double(forKey: legacyDatingStartDayKey)
    guard interval > 0 else { return nil }
    return DatingStartDayStore.clamp(Date(timeIntervalSince1970: interval))
  }

  private static func defaultApplicationSupportDirectory(fileManager: FileManager) -> URL {
    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return baseURL.appendingPathComponent("Dear Diary", isDirectory: true)
  }
}
