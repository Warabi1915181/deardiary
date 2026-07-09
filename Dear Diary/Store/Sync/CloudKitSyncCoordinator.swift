import CloudKit
import Foundation

enum PartnerSyncStatus: Equatable {
  case notSynced
  case invitePartner
  case waitingForPartner
  case synced(partnerName: String?)
  case syncing
  case offlineChangesSaved
  case syncFailed(message: String)

  var title: String {
    switch self {
    case .notSynced: return "Not Synced"
    case .invitePartner: return "Invite Partner"
    case .waitingForPartner: return "Waiting for Partner"
    case .synced(let partnerName):
      if let partnerName, !partnerName.isEmpty {
        return "Synced with \(partnerName)"
      }
      return "Synced"
    case .syncing: return "Syncing"
    case .offlineChangesSaved: return "Offline Changes Saved"
    case .syncFailed: return "Sync Failed, Will Retry"
    }
  }

  var message: String {
    switch self {
    case .notSynced:
      return "Enable partner sync to share your diary through iCloud."
    case .invitePartner:
      return "Invite your partner to start sharing this diary."
    case .waitingForPartner:
      return "Waiting for your partner to accept the iCloud invitation."
    case .synced:
      return "Your shared diary stays up to date through iCloud."
    case .syncing:
      return "Syncing your latest changes."
    case .offlineChangesSaved:
      return "Changes are saved on this device and will sync when iCloud is available."
    case .syncFailed(let message):
      return message
    }
  }
}

struct CloudKitSyncPersistedState: Codable {
  var privateEngineState: CKSyncEngine.State.Serialization?
  var sharedEngineState: CKSyncEngine.State.Serialization?
  /// Encoded CKRecord system fields (change tags) keyed by recordName, so a
  /// record's server change tag survives app relaunches. Without this, edits to
  /// existing records are sent without a change tag and rejected as
  /// `serverRecordChanged`.
  var recordSystemFields: [String: Data] = [:]
}

extension CKRecord {
  /// The record's server-managed system fields (recordID, change tag, etc.),
  /// encoded for persistence. Field values are NOT included.
  func encodedSystemFields() -> Data {
    let coder = NSKeyedArchiver(requiringSecureCoding: true)
    encodeSystemFields(with: coder)
    coder.finishEncoding()
    return coder.encodedData
  }

  static func withSystemFields(from data: Data) -> CKRecord? {
    guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
    coder.requiresSecureCoding = true
    let record = CKRecord(coder: coder)
    coder.finishDecoding()
    return record
  }
}

@MainActor
@Observable
final class AppEnvironment {
  let coupleSpaceStore: CoupleSpaceStore
  let diaryStore: DiaryStore
  let toDoStore: ToDoStore
  let syncCoordinator: CloudKitSyncCoordinator

  init(
    coupleSpaceStore: CoupleSpaceStore = CoupleSpaceStore(),
    diaryStore: DiaryStore = DiaryStore(),
    toDoStore: ToDoStore = ToDoStore()
  ) {
    self.coupleSpaceStore = coupleSpaceStore
    self.diaryStore = diaryStore
    self.toDoStore = toDoStore
    self.syncCoordinator = CloudKitSyncCoordinator(
      coupleSpaceStore: coupleSpaceStore,
      diaryStore: diaryStore,
      toDoStore: toDoStore
    )
    wireStoreCallbacks()
  }

  private func wireStoreCallbacks() {
    coupleSpaceStore.onRecordsChanged = { [weak syncCoordinator] references in
      syncCoordinator?.enqueueLocalChanges(references)
    }
    diaryStore.onRecordsChanged = { [weak syncCoordinator] references in
      syncCoordinator?.enqueueLocalChanges(references)
    }
    toDoStore.onRecordsChanged = { [weak syncCoordinator] references in
      syncCoordinator?.enqueueLocalChanges(references)
    }
  }
}

@MainActor
@Observable
final class CloudKitSyncCoordinator {
  static let containerIdentifier = CloudKitSyncService.containerIdentifier

  private(set) var accountAvailability: CloudKitAccountAvailability = .unknown
  private(set) var partnerSyncStatus: PartnerSyncStatus = .notSynced
  private(set) var isRefreshingAccountStatus = false
  private(set) var pendingShare: CKShare?
  private(set) var pendingShareContainer: CKContainer?
  var showPartnerMergePrompt = false

  @ObservationIgnored private let coupleSpaceStore: CoupleSpaceStore
  @ObservationIgnored private let diaryStore: DiaryStore
  @ObservationIgnored private let toDoStore: ToDoStore
  @ObservationIgnored private let container: CKContainer
  @ObservationIgnored private let syncStateURL: URL
  @ObservationIgnored private let fileManager: FileManager

  @ObservationIgnored private var syncState = CloudKitSyncPersistedState()
  @ObservationIgnored private var privateSyncEngine: CKSyncEngine?
  @ObservationIgnored private var sharedSyncEngine: CKSyncEngine?
  @ObservationIgnored private var rootRecordCache: CKRecord?
  @ObservationIgnored private var lastKnownRecords: [CKRecord.ID: CKRecord] = [:]

  init(
    coupleSpaceStore: CoupleSpaceStore,
    diaryStore: DiaryStore,
    toDoStore: ToDoStore,
    container: CKContainer = CKContainer(identifier: CloudKitSyncCoordinator.containerIdentifier),
    fileManager: FileManager = .default
  ) {
    self.coupleSpaceStore = coupleSpaceStore
    self.diaryStore = diaryStore
    self.toDoStore = toDoStore
    self.container = container
    self.fileManager = fileManager

    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    syncStateURL = baseURL
      .appendingPathComponent("Dear Diary", isDirectory: true)
      .appendingPathComponent("cloudkit.sync.state.v1.json")

    loadSyncState()
    refreshPartnerSyncStatus()
    showPartnerMergePrompt = coupleSpaceStore.pendingPartnerMergePrompt

    Task {
      await refreshAccountStatus()
      await bootstrapSyncEnginesIfNeeded()
    }
  }

  func reportSyncFailure(_ message: String) {
    partnerSyncStatus = .syncFailed(message: message)
  }

  func refreshAccountStatus() async {
    isRefreshingAccountStatus = true
    defer { isRefreshingAccountStatus = false }

    do {
      let status = try await container.accountStatus()
      accountAvailability = CloudKitAccountAvailability(status)
      refreshPartnerSyncStatus()
    } catch {
      accountAvailability = .error(error.localizedDescription)
    }
  }

  func invitePartner() async throws {
    guard accountAvailability.isAvailable else {
      throw CloudKitSyncError.iCloudUnavailable
    }

    partnerSyncStatus = .syncing
    let space = coupleSpaceStore.ensureCoupleSpace()
    _ = diaryStore.assignCoupleSpaceID(space.id)
    _ = toDoStore.assignCoupleSpaceID(space.id)

    let zone = CKRecordZone(zoneName: CloudKitRecordTypes.zoneName)
    let privateDatabase = container.privateCloudDatabase
    _ = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])

    let zoneID = zone.zoneID
    let rootRecord = CloudKitRecordMapper.coupleSpaceRecord(from: space, zoneID: zoneID)
    rootRecordCache = rootRecord
    rememberRecord(rootRecord)

    var recordsToSave: [CKRecord] = [rootRecord]
    recordsToSave.append(contentsOf: buildChildRecords(for: space, rootRecord: rootRecord, zoneID: zoneID))

    let share = CKShare(rootRecord: rootRecord)
    share[CKShare.SystemFieldKey.title] = "Dear Diary"
    share.publicPermission = .none

    let saved = try await privateDatabase.modifyRecords(saving: recordsToSave + [share], deleting: [])
    for (_, result) in saved.saveResults {
      if case .success(let record) = result {
        rememberRecord(record)
        if record is CKShare {
          pendingShare = record as? CKShare
        }
        if record.recordType == CloudKitRecordTypes.coupleSpace {
          rootRecordCache = record
        }
      }
    }

    coupleSpaceStore.setSyncConnection(
      SyncConnection(
        role: .owner,
        zoneName: zoneID.zoneName,
        zoneOwnerName: zoneID.ownerName,
        shareRecordName: pendingShare?.recordID.recordName,
        partnerDisplayName: nil,
        isActive: true
      )
    )

    initializePrivateSyncEngine()
    enqueueAllLocalRecords(for: space.id)
    try await sendChanges()

    pendingShareContainer = container
    partnerSyncStatus = .invitePartner
  }

  func handleAcceptedShare(_ metadata: CKShare.Metadata) async throws {
    guard accountAvailability.isAvailable else {
      throw CloudKitSyncError.iCloudUnavailable
    }

    partnerSyncStatus = .syncing
    try await container.accept(metadata)

    let zoneID = metadata.share.recordID.zoneID
    coupleSpaceStore.setSyncConnection(
      SyncConnection(
        role: .participant,
        zoneName: zoneID.zoneName,
        zoneOwnerName: zoneID.ownerName,
        shareRecordName: metadata.share.recordID.recordName,
        partnerDisplayName: metadata.ownerIdentity.nameComponents?.formatted(),
        isActive: true
      )
    )

    initializeSharedSyncEngine()
    try await fetchChanges()
    refreshPartnerSyncStatus()

    if hasLocalUnsharedData {
      coupleSpaceStore.setPendingPartnerMergePrompt(true)
      showPartnerMergePrompt = true
    }
  }

  func mergeLocalDataIntoSharedDiary() async {
    guard let space = coupleSpaceStore.coupleSpace else { return }

    var references = diaryStore.assignCoupleSpaceID(space.id)
    references.formUnion(toDoStore.assignCoupleSpaceID(space.id))
    references.insert(SyncRecordReference(kind: .coupleSpace, id: space.id))

    coupleSpaceStore.setPendingPartnerMergePrompt(false)
    showPartnerMergePrompt = false
    enqueueLocalChanges(references)
    partnerSyncStatus = .syncing

    do {
      try await sendChanges()
      refreshPartnerSyncStatus()
    } catch {
      partnerSyncStatus = .syncFailed(message: error.localizedDescription)
    }
  }

  func keepLocalDataSeparate() {
    coupleSpaceStore.setPendingPartnerMergePrompt(false)
    showPartnerMergePrompt = false
  }

  func leaveSharedDiary() async {
    coupleSpaceStore.leaveSharedDiary()
    privateSyncEngine = nil
    sharedSyncEngine = nil
    rootRecordCache = nil
    lastKnownRecords = [:]
    pendingShare = nil
    pendingShareContainer = nil
    showPartnerMergePrompt = false
    syncState = CloudKitSyncPersistedState()
    saveSyncState()
    refreshPartnerSyncStatus()
  }

  func enqueueLocalChanges(_ references: Set<SyncRecordReference>) {
    guard coupleSpaceStore.isSynced else { return }

    let pending = references.map { CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID(for: $0)) }
    if coupleSpaceStore.syncConnection?.role == .owner {
      privateSyncEngine?.state.add(pendingRecordZoneChanges: pending)
    } else {
      sharedSyncEngine?.state.add(pendingRecordZoneChanges: pending)
    }

    if accountAvailability.isAvailable {
      partnerSyncStatus = .syncing
      Task {
        try? await sendChanges()
        refreshPartnerSyncStatus()
      }
    } else {
      partnerSyncStatus = .offlineChangesSaved
    }
  }

  func sendChanges() async throws {
    if coupleSpaceStore.syncConnection?.role == .owner {
      try await privateSyncEngine?.sendChanges(CKSyncEngine.SendChangesOptions())
    } else {
      try await sharedSyncEngine?.sendChanges(CKSyncEngine.SendChangesOptions())
    }
  }

  func fetchChanges() async throws {
    if coupleSpaceStore.syncConnection?.role == .owner {
      try await privateSyncEngine?.fetchChanges(CKSyncEngine.FetchChangesOptions())
    } else {
      try await sharedSyncEngine?.fetchChanges(CKSyncEngine.FetchChangesOptions())
    }
  }

  var hasLocalUnsharedData: Bool {
    let hasDiary = diaryStore.entries.contains { $0.coupleSpaceID == nil }
    let hasTodos = toDoStore.state.items.contains { $0.deletedAt == nil && $0.coupleSpaceID == nil }
      || toDoStore.state.categories.contains {
        $0.deletedAt == nil && $0.id != ToDoStore.uncategorizedCategoryID && $0.coupleSpaceID == nil
      }
    return hasDiary || hasTodos
  }

  private func bootstrapSyncEnginesIfNeeded() async {
    guard accountAvailability.isAvailable, let connection = coupleSpaceStore.syncConnection else { return }

    switch connection.role {
    case .owner:
      initializePrivateSyncEngine()
    case .participant:
      initializeSharedSyncEngine()
    }

    do {
      try await fetchChanges()
    } catch {
      partnerSyncStatus = .syncFailed(message: error.localizedDescription)
    }
  }

  private func initializePrivateSyncEngine() {
    var configuration = CKSyncEngine.Configuration(
      database: container.privateCloudDatabase,
      stateSerialization: syncState.privateEngineState,
      delegate: self
    )
    configuration.automaticallySync = true
    privateSyncEngine = CKSyncEngine(configuration)
  }

  private func initializeSharedSyncEngine() {
    var configuration = CKSyncEngine.Configuration(
      database: container.sharedCloudDatabase,
      stateSerialization: syncState.sharedEngineState,
      delegate: self
    )
    configuration.automaticallySync = true
    sharedSyncEngine = CKSyncEngine(configuration)
  }

  private func refreshPartnerSyncStatus() {
    guard accountAvailability.isAvailable else {
      if coupleSpaceStore.isSynced {
        partnerSyncStatus = .offlineChangesSaved
      } else {
        partnerSyncStatus = .notSynced
      }
      return
    }

    guard let connection = coupleSpaceStore.syncConnection else {
      partnerSyncStatus = .notSynced
      return
    }

    switch connection.role {
    case .owner where pendingShare != nil:
      partnerSyncStatus = .invitePartner
    case .owner:
      partnerSyncStatus = .synced(partnerName: connection.partnerDisplayName)
    case .participant:
      partnerSyncStatus = .synced(partnerName: connection.partnerDisplayName)
    }
  }

  private func enqueueAllLocalRecords(for coupleSpaceID: UUID) {
    var references = diaryStore.allSyncRecords(coupleSpaceID: coupleSpaceID)
    references.formUnion(toDoStore.allSyncRecords(coupleSpaceID: coupleSpaceID))
    references.insert(SyncRecordReference(kind: .coupleSpace, id: coupleSpaceID))
    enqueueLocalChanges(references)
  }

  private func buildChildRecords(for space: CoupleSpace, rootRecord: CKRecord, zoneID: CKRecordZone.ID) -> [CKRecord] {
    var records: [CKRecord] = []

    for entry in diaryStore.state.entries where entry.coupleSpaceID == space.id {
      let entryRecord = CloudKitRecordMapper.diaryEntryRecord(from: entry, zoneID: zoneID, parent: rootRecord)
      records.append(entryRecord)
      for photo in entry.photos {
        let assetURL = diaryStore.photoURL(for: photo)
        let photoRecord = CloudKitRecordMapper.diaryPhotoRecord(
          from: photo,
          entryID: entry.id,
          coupleSpaceID: space.id,
          zoneID: zoneID,
          parent: entryRecord,
          assetURL: FileManager.default.fileExists(atPath: assetURL.path) ? assetURL : nil
        )
        records.append(photoRecord)
      }
    }

    for category in toDoStore.state.categories where category.coupleSpaceID == space.id {
      records.append(CloudKitRecordMapper.toDoCategoryRecord(from: category, zoneID: zoneID, parent: rootRecord))
    }

    for item in toDoStore.state.items where item.coupleSpaceID == space.id {
      records.append(CloudKitRecordMapper.toDoItemRecord(from: item, zoneID: zoneID, parent: rootRecord))
    }

    return records
  }

  private func recordID(for reference: SyncRecordReference) -> CKRecord.ID {
    let ownerName = coupleSpaceStore.syncConnection?.zoneOwnerName ?? CKCurrentUserDefaultName
    let zoneID = CloudKitRecordMapper.zoneID(ownerName: ownerName)
    return CloudKitRecordMapper.recordID(for: reference, zoneID: zoneID)
  }

  private func rootRecord(for zoneID: CKRecordZone.ID) -> CKRecord? {
    if let rootRecordCache, rootRecordCache.recordID.zoneID == zoneID {
      return rootRecordCache
    }
    if let space = coupleSpaceStore.coupleSpace {
      let record = CloudKitRecordMapper.coupleSpaceRecord(from: space, zoneID: zoneID)
      rootRecordCache = record
      return record
    }
    return nil
  }

  private func recordToSave(for recordID: CKRecord.ID) -> CKRecord? {
    guard let reference = CloudKitRecordMapper.reference(from: recordID) else { return nil }
    guard let zoneID = coupleSpaceStore.syncConnection.map({
      CloudKitRecordMapper.zoneID(ownerName: $0.zoneOwnerName)
    }) else {
      return nil
    }
    guard let root = rootRecord(for: zoneID) else { return nil }

    switch reference.kind {
    case .coupleSpace:
      guard let space = coupleSpaceStore.coupleSpace else { return nil }
      let record = baseRecord(
        recordID: recordID,
        type: CloudKitRecordTypes.coupleSpace,
        populate: {
          CloudKitRecordMapper.coupleSpaceRecord(from: space, zoneID: zoneID)
        }
      )
      return record

    case .diaryEntry:
      guard let entry = diaryStore.entryRecord(id: reference.id) else {
        return deletedPlaceholder(recordID: recordID, type: CloudKitRecordTypes.diaryEntry)
      }
      return baseRecord(
        recordID: recordID,
        type: CloudKitRecordTypes.diaryEntry,
        populate: {
          CloudKitRecordMapper.diaryEntryRecord(from: entry, zoneID: zoneID, parent: root)
        }
      )

    case .diaryPhoto:
      guard
        let entry = diaryStore.state.entries.first(where: { entry in
          entry.photos.contains(where: { $0.id == reference.id })
        }),
        let photo = entry.photos.first(where: { $0.id == reference.id })
      else {
        return deletedPlaceholder(recordID: recordID, type: CloudKitRecordTypes.diaryPhoto)
      }
      let entryRecordID = CloudKitRecordMapper.recordID(
        for: SyncRecordReference(kind: .diaryEntry, id: entry.id),
        zoneID: zoneID
      )
      let parent = lastKnownRecords[entryRecordID]
        ?? CloudKitRecordMapper.diaryEntryRecord(from: entry, zoneID: zoneID, parent: root)
      let assetURL = diaryStore.photoURL(for: photo)
      return baseRecord(
        recordID: recordID,
        type: CloudKitRecordTypes.diaryPhoto,
        populate: {
          CloudKitRecordMapper.diaryPhotoRecord(
            from: photo,
            entryID: entry.id,
            coupleSpaceID: entry.coupleSpaceID ?? coupleSpaceStore.coupleSpace?.id ?? UUID(),
            zoneID: zoneID,
            parent: parent,
            assetURL: FileManager.default.fileExists(atPath: assetURL.path) ? assetURL : nil
          )
        }
      )

    case .toDoCategory:
      guard let category = toDoStore.categoryRecord(id: reference.id) else {
        return deletedPlaceholder(recordID: recordID, type: CloudKitRecordTypes.toDoCategory)
      }
      return baseRecord(
        recordID: recordID,
        type: CloudKitRecordTypes.toDoCategory,
        populate: {
          CloudKitRecordMapper.toDoCategoryRecord(from: category, zoneID: zoneID, parent: root)
        }
      )

    case .toDoItem:
      guard let item = toDoStore.itemRecord(id: reference.id) else {
        return deletedPlaceholder(recordID: recordID, type: CloudKitRecordTypes.toDoItem)
      }
      return baseRecord(
        recordID: recordID,
        type: CloudKitRecordTypes.toDoItem,
        populate: {
          CloudKitRecordMapper.toDoItemRecord(from: item, zoneID: zoneID, parent: root)
        }
      )
    }
  }

  private func baseRecord(
    recordID: CKRecord.ID,
    type: String,
    populate: () -> CKRecord
  ) -> CKRecord {
    if let known = lastKnownRecords[recordID] {
      let populated = populate()
      for key in populated.allKeys() {
        known[key] = populated[key]
      }
      return known
    }
    return populate()
  }

  private func deletedPlaceholder(recordID: CKRecord.ID, type: String) -> CKRecord {
    let record = baseRecord(recordID: recordID, type: type) {
      CKRecord(recordType: type, recordID: recordID)
    }
    record[CloudKitField.deletedAt] = Date()
    return record
  }

  private func applyFetchedRecord(_ record: CKRecord) {
    rememberRecord(record)

    switch record.recordType {
    case CloudKitRecordTypes.coupleSpace:
      if let space = CloudKitRecordMapper.coupleSpace(from: record) {
        _ = coupleSpaceStore.applyRemoteCoupleSpace(space)
        rootRecordCache = record
      }

    case CloudKitRecordTypes.diaryEntry:
      if var entry = CloudKitRecordMapper.diaryEntry(from: record) {
        if let existing = diaryStore.entryRecord(id: entry.id) {
          entry.photos = existing.photos
        }
        _ = diaryStore.applyRemoteEntry(entry)
      }

    case CloudKitRecordTypes.diaryPhoto:
      guard
        let photo = CloudKitRecordMapper.diaryPhoto(from: record),
        let entryID = CloudKitRecordMapper.diaryEntryID(from: record),
        var entry = diaryStore.entryRecord(id: entryID)
      else {
        return
      }

      if let asset = record[CloudKitField.asset] as? CKAsset, let sourceURL = asset.fileURL {
        let data = (try? Data(contentsOf: sourceURL)) ?? Data()
        try? diaryStore.saveDownloadedPhoto(data: data, photo: photo, fileExtension: photo.filename.split(separator: ".").last.map(String.init) ?? "jpg")
      }

      if !entry.photos.contains(where: { $0.id == photo.id }) {
        entry.photos.append(photo)
      } else if let index = entry.photos.firstIndex(where: { $0.id == photo.id }) {
        entry.photos[index] = photo
      }
      entry.updatedAt = record[CloudKitField.updatedAt] as? Date ?? entry.updatedAt
      _ = diaryStore.applyRemoteEntry(entry)

    case CloudKitRecordTypes.toDoCategory:
      if let category = CloudKitRecordMapper.toDoCategory(from: record) {
        _ = toDoStore.applyRemoteCategory(category)
      }

    case CloudKitRecordTypes.toDoItem:
      if let item = CloudKitRecordMapper.toDoItem(from: record) {
        _ = toDoStore.applyRemoteItem(item)
      }

    default:
      break
    }
  }

  private func loadSyncState() {
    guard
      let data = try? Data(contentsOf: syncStateURL),
      let decoded = try? JSONDecoder().decode(CloudKitSyncPersistedState.self, from: data)
    else {
      return
    }
    syncState = decoded
    rehydrateKnownRecords()
  }

  /// Rebuilds the in-memory `lastKnownRecords` (change tags) from persisted
  /// system fields, so edits after a relaunch carry the correct change tag.
  private func rehydrateKnownRecords() {
    for (_, data) in syncState.recordSystemFields {
      guard let record = CKRecord.withSystemFields(from: data) else { continue }
      lastKnownRecords[record.recordID] = record
    }
  }

  /// Records the server version of a CKRecord (in memory + persisted system
  /// fields) so future saves reuse its change tag.
  private func rememberRecord(_ record: CKRecord) {
    lastKnownRecords[record.recordID] = record
    syncState.recordSystemFields[record.recordID.recordName] = record.encodedSystemFields()
  }

  private func saveSyncState() {
    do {
      try fileManager.createDirectory(
        at: syncStateURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(syncState)
      try data.write(to: syncStateURL, options: [.atomic])
    } catch {
      assertionFailure("Failed to save CloudKit sync state: \(error)")
    }
  }
}

enum CloudKitSyncError: LocalizedError {
  case iCloudUnavailable

  var errorDescription: String? {
    switch self {
    case .iCloudUnavailable:
      return "iCloud is not available on this device."
    }
  }
}

extension CloudKitSyncCoordinator: CKSyncEngineDelegate {
  nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
    await MainActor.run {
      self.handleEventOnMainActor(event, syncEngine: syncEngine)
    }
  }

  nonisolated func nextRecordZoneChangeBatch(
    _ context: CKSyncEngine.SendChangesContext,
    syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    await nextRecordZoneChangeBatchOnMainActor(context, syncEngine: syncEngine)
  }

  private func handleEventOnMainActor(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
    switch event {
    case .stateUpdate(let update):
      if syncEngine === privateSyncEngine {
        syncState.privateEngineState = update.stateSerialization
      } else if syncEngine === sharedSyncEngine {
        syncState.sharedEngineState = update.stateSerialization
      }
      saveSyncState()

    case .fetchedRecordZoneChanges(let changes):
      for modification in changes.modifications {
        applyFetchedRecord(modification.record)
      }
      saveSyncState()
      refreshPartnerSyncStatus()

    case .sentRecordZoneChanges(let results):
      for savedRecord in results.savedRecords {
        rememberRecord(savedRecord)
      }

      var recoveredChanges: [CKSyncEngine.PendingRecordZoneChange] = []
      for failure in results.failedRecordSaves {
        // On a change-tag conflict CloudKit returns the current server record.
        // Adopt its change tag, reapply our field values, and requeue the save
        // instead of dropping the edit.
        guard failure.error.code == .serverRecordChanged, let serverRecord = failure.error.serverRecord else { continue }
        let localRecord = failure.record
        for key in localRecord.allKeys() {
          serverRecord[key] = localRecord[key]
        }
        rememberRecord(serverRecord)
        recoveredChanges.append(.saveRecord(serverRecord.recordID))
      }

      if !recoveredChanges.isEmpty {
        syncEngine.state.add(pendingRecordZoneChanges: recoveredChanges)
        Task { try? await sendChanges() }
      }

      saveSyncState()
      refreshPartnerSyncStatus()

    case .willFetchChanges, .didFetchChanges, .willSendChanges, .didSendChanges,
         .fetchedDatabaseChanges, .sentDatabaseChanges, .accountChange,
         .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
      break

    @unknown default:
      break
    }
  }

  private func nextRecordZoneChangeBatchOnMainActor(
    _ context: CKSyncEngine.SendChangesContext,
    syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
    guard !pending.isEmpty else { return nil }

    return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [weak self] recordID in
      await self?.recordToSave(for: recordID)
    }
  }
}
