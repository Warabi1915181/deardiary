import Foundation

enum MilestoneRecurrence: String, Codable, CaseIterable, Identifiable {
  case none
  case monthly
  case yearly

  var id: String { rawValue }

  var label: String {
    switch self {
    case .none: return "One time"
    case .monthly: return "Every month"
    case .yearly: return "Every year"
    }
  }
}

struct Milestone: Identifiable, Codable, Hashable, SyncStamped {
  var id: UUID
  var coupleSpaceID: UUID?
  var title: String
  var date: Date
  var note: String
  var recurrence: MilestoneRecurrence
  var icon: String
  var linkedDiaryEntryID: UUID?
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?
  var modifiedByDeviceID: String
  var version: Int
}

struct MilestonePersistedState: Codable {
  var milestones: [Milestone]
}

@Observable
final class MilestoneStore {
  static let schemaVersion = 1

  private(set) var state: MilestonePersistedState {
    didSet { save() }
  }

  private let storeURL: URL
  private let deviceID: String
  private let fileManager: FileManager
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  @ObservationIgnored var onRecordsChanged: ((Set<SyncRecordReference>) -> Void)?

  init(
    storeURL: URL? = nil,
    deviceID: String = AppDeviceIdentifier.current(),
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    self.deviceID = deviceID

    let baseURL = storeURL?.deletingLastPathComponent()
      ?? Self.defaultApplicationSupportDirectory(fileManager: fileManager)
    self.storeURL = storeURL ?? baseURL.appendingPathComponent("milestone.store.v1.json")

    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    if
      let data = try? Data(contentsOf: self.storeURL),
      let decoded = try? decoder.decode(MilestonePersistedState.self, from: data)
    {
      state = Self.normalize(decoded)
    } else {
      state = MilestonePersistedState(milestones: [])
      save()
    }
  }

  var milestones: [Milestone] {
    state.milestones
      .filter { $0.deletedAt == nil }
      .sorted(by: Self.sortMilestones)
  }

  func nextOccurrence(of milestone: Milestone, from referenceDate: Date = Date()) -> Date {
    Milestone.nextOccurrence(of: milestone, from: referenceDate)
  }

  @discardableResult
  func addMilestone(
    title: String,
    date: Date,
    note: String,
    recurrence: MilestoneRecurrence,
    icon: String
  ) -> UUID? {
    let normalizedTitle = normalizeTitle(title)
    guard !normalizedTitle.isEmpty else { return nil }

    let now = Date()
    let milestone = Milestone(
      id: UUID(),
      coupleSpaceID: nil,
      title: normalizedTitle,
      date: date,
      note: note.trimmingCharacters(in: .whitespacesAndNewlines),
      recurrence: recurrence,
      icon: icon,
      linkedDiaryEntryID: nil,
      createdAt: now,
      updatedAt: now,
      deletedAt: nil,
      modifiedByDeviceID: deviceID,
      version: Self.schemaVersion
    )
    state.milestones.append(milestone)
    notifyChanges(for: milestone)
    return milestone.id
  }

  @discardableResult
  func updateMilestone(
    id: UUID,
    title: String,
    date: Date,
    note: String,
    recurrence: MilestoneRecurrence,
    icon: String
  ) -> Bool {
    guard let index = state.milestones.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }

    let normalizedTitle = normalizeTitle(title)
    guard !normalizedTitle.isEmpty else { return false }

    state.milestones[index].title = normalizedTitle
    state.milestones[index].date = date
    state.milestones[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    state.milestones[index].recurrence = recurrence
    state.milestones[index].icon = icon
    state.milestones[index].updatedAt = Date()
    state.milestones[index].modifiedByDeviceID = deviceID
    state.milestones[index].version = Self.schemaVersion
    notifyChanges(for: state.milestones[index])
    return true
  }

  @discardableResult
  func setLinkedDiaryEntryID(_ id: UUID, entryID: UUID?) -> Bool {
    guard let index = state.milestones.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }
    state.milestones[index].linkedDiaryEntryID = entryID
    state.milestones[index].updatedAt = Date()
    state.milestones[index].modifiedByDeviceID = deviceID
    notifyChanges(for: state.milestones[index])
    return true
  }

  @discardableResult
  func softDeleteMilestone(id: UUID) -> Bool {
    guard let index = state.milestones.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
      return false
    }
    let now = Date()
    state.milestones[index].deletedAt = now
    state.milestones[index].updatedAt = now
    state.milestones[index].modifiedByDeviceID = deviceID
    notifyChanges(for: state.milestones[index])
    return true
  }

  func milestoneRecord(id: UUID) -> Milestone? {
    state.milestones.first(where: { $0.id == id })
  }

  func assignCoupleSpaceID(_ coupleSpaceID: UUID) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = []

    for index in state.milestones.indices where state.milestones[index].deletedAt == nil {
      guard state.milestones[index].coupleSpaceID != coupleSpaceID else { continue }
      state.milestones[index].coupleSpaceID = coupleSpaceID
      state.milestones[index].updatedAt = Date()
      state.milestones[index].modifiedByDeviceID = deviceID
      references.formUnion(notifyChanges(for: state.milestones[index]))
    }

    return references
  }

  func applyRemoteMilestone(_ remote: Milestone) -> Bool {
    if remote.deletedAt != nil {
      if let index = state.milestones.firstIndex(where: { $0.id == remote.id }) {
        state.milestones[index] = remote
      }
      return true
    }

    if let index = state.milestones.firstIndex(where: { $0.id == remote.id }) {
      let local = state.milestones[index]
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
      state.milestones[index] = remote
      return true
    }

    state.milestones.append(remote)
    return true
  }

  func allSyncRecords(coupleSpaceID: UUID) -> Set<SyncRecordReference> {
    var references: Set<SyncRecordReference> = []
    for milestone in state.milestones where milestone.coupleSpaceID == coupleSpaceID {
      references.insert(SyncRecordReference(kind: .milestone, id: milestone.id))
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
      assertionFailure("Failed to save milestone store: \(error)")
    }
  }

  @discardableResult
  private func notifyChanges(for milestone: Milestone) -> Set<SyncRecordReference> {
    let references: Set<SyncRecordReference> = [
      SyncRecordReference(kind: .milestone, id: milestone.id),
    ]
    onRecordsChanged?(references)
    return references
  }

  private func normalizeTitle(_ title: String) -> String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func normalize(_ state: MilestonePersistedState) -> MilestonePersistedState {
    MilestonePersistedState(
      milestones: state.milestones.map { milestone in
        var mutable = milestone
        mutable.title = milestone.title.trimmingCharacters(in: .whitespacesAndNewlines)
        mutable.note = milestone.note.trimmingCharacters(in: .whitespacesAndNewlines)
        mutable.version = max(milestone.version, schemaVersion)
        return mutable
      }
    )
  }

  private nonisolated static func sortMilestones(_ lhs: Milestone, _ rhs: Milestone) -> Bool {
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
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

extension Milestone {
  static func nextOccurrence(
    of milestone: Milestone,
    from referenceDate: Date = Date(),
    calendar: Calendar = .current
  ) -> Date {
    switch milestone.recurrence {
    case .none:
      return milestone.date

    case .monthly:
      let refDay = calendar.startOfDay(for: referenceDate)
      let targetDay = calendar.component(.day, from: milestone.date)
      let monthComponents = calendar.dateComponents([.year, .month], from: refDay)
      guard let monthStart = calendar.date(from: monthComponents) else { return milestone.date }

      for monthOffset in 0 ... 1 {
        if
          let month = calendar.date(byAdding: .month, value: monthOffset, to: monthStart),
          let candidate = Self.clampedDate(day: targetDay, inMonthOf: month, calendar: calendar),
          candidate >= refDay
        {
          return candidate
        }
      }

      return milestone.date

    case .yearly:
      let refDay = calendar.startOfDay(for: referenceDate)
      let anchorComponents = calendar.dateComponents([.month, .day], from: milestone.date)
      guard let month = anchorComponents.month, let day = anchorComponents.day else {
        return milestone.date
      }
      let refYear = calendar.component(.year, from: refDay)

      for yearOffset in 0 ... 1 {
        let year = refYear + yearOffset
        if
          let candidate = Self.date(year: year, month: month, day: day, calendar: calendar),
          candidate >= refDay
        {
          return candidate
        }
      }

      return Self.date(year: refYear + 1, month: month, day: day, calendar: calendar) ?? milestone.date
    }
  }

  /// Builds `day` within the month containing `monthReference`, clamping to the
  /// month's last day when it is shorter (the 31st in a 30-day month, or the
  /// 29th–31st in February) — the monthly analogue of the yearly Feb-29 fold.
  private static func clampedDate(day: Int, inMonthOf monthReference: Date, calendar: Calendar) -> Date? {
    guard let range = calendar.range(of: .day, in: .month, for: monthReference) else { return nil }
    var components = calendar.dateComponents([.year, .month], from: monthReference)
    components.day = min(day, range.upperBound - 1)
    return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
  }

  private static func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
    let safeDay = (month == 2 && day == 29 && !isLeapYear(year)) ? 28 : day
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = safeDay
    return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
  }

  private static func isLeapYear(_ year: Int) -> Bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
  }
}
