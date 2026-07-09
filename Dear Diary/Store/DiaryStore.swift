import Foundation

enum DiaryMood: String, Codable, CaseIterable, Identifiable {
  case happy
  case cozy
  case grateful
  case excited
  case calm
  case sad
  case tired
  case stressed

  var id: String { rawValue }

  var label: String {
    switch self {
    case .happy: return "Happy"
    case .cozy: return "Cozy"
    case .grateful: return "Grateful"
    case .excited: return "Excited"
    case .calm: return "Calm"
    case .sad: return "Sad"
    case .tired: return "Tired"
    case .stressed: return "Stressed"
    }
  }
}

struct DiaryPhoto: Identifiable, Codable, Hashable {
  var id: UUID
  var filename: String
  var createdAt: Date
}

struct DiaryEntry: Identifiable, Codable, Hashable, SyncStamped {
  var id: UUID
  var coupleSpaceID: UUID?
  var title: String
  var body: String
  var entryDate: Date
  var mood: DiaryMood?
  var tags: [String]
  var photos: [DiaryPhoto]
  var isFavorite: Bool
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?
  var modifiedByDeviceID: String
  var version: Int
}

struct DiaryPersistedState: Codable {
  var entries: [DiaryEntry]
}

struct DiaryPhotoPayload {
  var data: Data
  var fileExtension: String
}

@Observable
final class DiaryStore {
  static let schemaVersion = 1

  private(set) var state: DiaryPersistedState {
    didSet { save() }
  }

  private let storeURL: URL
  private let photosDirectoryURL: URL
  private let deviceID: String
  private let fileManager: FileManager
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  @ObservationIgnored var onRecordsChanged: ((Set<SyncRecordReference>) -> Void)?

  init(
    storeURL: URL? = nil,
    photosDirectoryURL: URL? = nil,
    deviceID: String = AppDeviceIdentifier.current(),
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    self.deviceID = deviceID

    let baseURL = storeURL?.deletingLastPathComponent()
      ?? Self.defaultApplicationSupportDirectory(fileManager: fileManager)
    self.storeURL = storeURL ?? baseURL.appendingPathComponent("diary.store.v1.json")
    self.photosDirectoryURL = photosDirectoryURL ?? baseURL.appendingPathComponent("DiaryPhotos")

    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    if
      let data = try? Data(contentsOf: self.storeURL),
      let decoded = try? decoder.decode(DiaryPersistedState.self, from: data)
    {
      self.state = Self.normalize(decoded)
    } else {
      self.state = DiaryPersistedState(entries: [])
      save()
    }
  }

  var entries: [DiaryEntry] {
    state.entries
      .filter { $0.deletedAt == nil }
      .sorted(by: Self.sortEntries)
  }

  var latestEntry: DiaryEntry? {
    entries.first
  }

  var allTags: [String] {
    let uniqueTags = Set(entries.flatMap(\.tags))
    return uniqueTags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  func entries(matching searchText: String, favoriteOnly: Bool = false) -> [DiaryEntry] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return entries.filter { entry in
      guard !favoriteOnly || entry.isFavorite else { return false }
      guard !query.isEmpty else { return true }
      return entry.matches(query: query)
    }
  }

  func photoURL(for photo: DiaryPhoto) -> URL {
    photosDirectoryURL.appendingPathComponent(photo.filename)
  }

  @discardableResult
  func addEntry(
    title: String,
    body: String,
    entryDate: Date,
    mood: DiaryMood?,
    tags: [String],
    photoPayloads: [DiaryPhotoPayload] = []
  ) throws -> UUID? {
    let normalizedTitle = normalizeTitle(title, body: body)
    let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedTitle.isEmpty || !normalizedBody.isEmpty else { return nil }

    let now = Date()
    let photos = try savePhotoPayloads(photoPayloads)
    let entry = DiaryEntry(
      id: UUID(),
      coupleSpaceID: nil,
      title: normalizedTitle,
      body: normalizedBody,
      entryDate: entryDate,
      mood: mood,
      tags: normalizeTags(tags),
      photos: photos,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: deviceID,
      version: Self.schemaVersion
    )
    state.entries.append(entry)
    notifyChanges(for: entry)
    return entry.id
  }

  func updateEntry(
    id: UUID,
    title: String,
    body: String,
    entryDate: Date,
    mood: DiaryMood?,
    tags: [String],
    photosToKeep: [DiaryPhoto],
    newPhotoPayloads: [DiaryPhotoPayload] = []
  ) throws -> Bool {
    guard let index = state.entries.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }

    let normalizedTitle = normalizeTitle(title, body: body)
    let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedTitle.isEmpty || !normalizedBody.isEmpty else { return false }

    let existingPhotos = state.entries[index].photos
    let keepIDs = Set(photosToKeep.map(\.id))
    for photo in existingPhotos where !keepIDs.contains(photo.id) {
      removePhotoFile(photo)
    }

    let appendedPhotos = try savePhotoPayloads(newPhotoPayloads)
    state.entries[index].title = normalizedTitle
    state.entries[index].body = normalizedBody
    state.entries[index].entryDate = entryDate
    state.entries[index].mood = mood
    state.entries[index].tags = normalizeTags(tags)
    state.entries[index].photos = photosToKeep + appendedPhotos
    state.entries[index].updatedAt = Date()
    state.entries[index].modifiedByDeviceID = deviceID
    state.entries[index].version = Self.schemaVersion
    notifyChanges(for: state.entries[index])
    return true
  }

  func setFavorite(_ id: UUID, isFavorite: Bool) -> Bool {
    guard let index = state.entries.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }
    state.entries[index].isFavorite = isFavorite
    state.entries[index].updatedAt = Date()
    state.entries[index].modifiedByDeviceID = deviceID
    notifyChanges(for: state.entries[index])
    return true
  }

  func softDeleteEntry(id: UUID) -> Bool {
    guard let index = state.entries.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }
    let now = Date()
    state.entries[index].deletedAt = now
    state.entries[index].updatedAt = now
    state.entries[index].modifiedByDeviceID = deviceID
    notifyChanges(for: state.entries[index])
    return true
  }

  func entryRecord(id: UUID) -> DiaryEntry? {
    state.entries.first(where: { $0.id == id })
  }

  func assignCoupleSpaceID(_ coupleSpaceID: UUID) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = []

    for index in state.entries.indices where state.entries[index].deletedAt == nil {
      guard state.entries[index].coupleSpaceID != coupleSpaceID else { continue }
      state.entries[index].coupleSpaceID = coupleSpaceID
      state.entries[index].updatedAt = Date()
      state.entries[index].modifiedByDeviceID = deviceID
      references.formUnion(notifyChanges(for: state.entries[index]))
    }

    return references
  }

  func applyRemoteEntry(_ remote: DiaryEntry) -> Bool {
    if remote.deletedAt != nil {
      if let index = state.entries.firstIndex(where: { $0.id == remote.id }) {
        let existingPhotos = state.entries[index].photos
        for photo in existingPhotos where !remote.photos.contains(where: { $0.id == photo.id }) {
          removePhotoFile(photo)
        }
        state.entries[index] = remote
      }
      return true
    }

    if let index = state.entries.firstIndex(where: { $0.id == remote.id }) {
      let local = state.entries[index]
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

      let removedPhotos = local.photos.filter { photo in
        !remote.photos.contains(where: { $0.id == photo.id })
      }
      for photo in removedPhotos {
        removePhotoFile(photo)
      }
      state.entries[index] = remote
      return true
    }

    state.entries.append(remote)
    return true
  }

  func saveDownloadedPhoto(data: Data, photo: DiaryPhoto, fileExtension: String) throws {
    try fileManager.createDirectory(at: photosDirectoryURL, withIntermediateDirectories: true)
    let safeExtension = sanitizeFileExtension(fileExtension)
    let filename = photo.filename.isEmpty ? "\(photo.id.uuidString).\(safeExtension)" : photo.filename
    let url = photosDirectoryURL.appendingPathComponent(filename)
    try data.write(to: url, options: [.atomic])
  }

  func allSyncRecords(coupleSpaceID: UUID) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = []
    for entry in state.entries where entry.coupleSpaceID == coupleSpaceID {
      references.insert(SyncRecordReference(kind: .diaryEntry, id: entry.id))
      for photo in entry.photos {
        references.insert(SyncRecordReference(kind: .diaryPhoto, id: photo.id))
      }
    }
    return references
  }

  private func savePhotoPayloads(_ payloads: [DiaryPhotoPayload]) throws -> [DiaryPhoto] {
    guard !payloads.isEmpty else { return [] }
    try fileManager.createDirectory(at: photosDirectoryURL, withIntermediateDirectories: true)

    return try payloads.map { payload in
      let id = UUID()
      let safeExtension = sanitizeFileExtension(payload.fileExtension)
      let filename = "\(id.uuidString).\(safeExtension)"
      let url = photosDirectoryURL.appendingPathComponent(filename)
      try payload.data.write(to: url, options: [.atomic])
      return DiaryPhoto(id: id, filename: filename, createdAt: Date())
    }
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
      assertionFailure("Failed to save diary store: \(error)")
    }
  }

  private func removePhotoFile(_ photo: DiaryPhoto) {
    try? fileManager.removeItem(at: photoURL(for: photo))
  }

  @discardableResult
  private func notifyChanges(for entry: DiaryEntry) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = [
      SyncRecordReference(kind: .diaryEntry, id: entry.id)
    ]
    for photo in entry.photos {
      references.insert(SyncRecordReference(kind: .diaryPhoto, id: photo.id))
    }
    onRecordsChanged?(references)
    return references
  }

  private func normalizeTitle(_ title: String, body: String) -> String {
    let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !normalizedTitle.isEmpty {
      return normalizedTitle
    }

    let bodyPreview = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !bodyPreview.isEmpty else { return "" }
    return "Untitled Memory"
  }

  private func normalizeTags(_ tags: [String]) -> [String] {
    var seen: Set<String> = []
    var normalized: [String] = []

    for tag in tags {
      let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !clean.isEmpty else { continue }
      let key = clean.lowercased()
      guard !seen.contains(key) else { continue }
      seen.insert(key)
      normalized.append(clean)
    }

    return normalized
  }

  private func sanitizeFileExtension(_ fileExtension: String) -> String {
    let clean = fileExtension
      .lowercased()
      .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    return clean.isEmpty ? "jpg" : clean
  }

  private static func normalize(_ state: DiaryPersistedState) -> DiaryPersistedState {
    DiaryPersistedState(
      entries: state.entries.map { entry in
        var mutable = entry
        mutable.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        mutable.body = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        mutable.tags = Array(
          NSOrderedSet(
            array: entry.tags
              .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
              .filter { !$0.isEmpty }
          )
        ) as? [String] ?? []
        mutable.version = max(entry.version, schemaVersion)
        return mutable
      }
    )
  }

  private static func sortEntries(_ lhs: DiaryEntry, _ rhs: DiaryEntry) -> Bool {
    if lhs.entryDate != rhs.entryDate {
      return lhs.entryDate > rhs.entryDate
    }
    if lhs.updatedAt != rhs.updatedAt {
      return lhs.updatedAt > rhs.updatedAt
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  private static func defaultApplicationSupportDirectory(fileManager: FileManager) -> URL {
    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return baseURL.appendingPathComponent("Dear Diary", isDirectory: true)
  }
}

private extension DiaryEntry {
  func matches(query: String) -> Bool {
    let lowercasedQuery = query.lowercased()
    if title.lowercased().contains(lowercasedQuery) { return true }
    if body.lowercased().contains(lowercasedQuery) { return true }
    if mood?.label.lowercased().contains(lowercasedQuery) == true { return true }
    return tags.contains { $0.lowercased().contains(lowercasedQuery) }
  }
}

