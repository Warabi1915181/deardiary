import Foundation

/// Chooses one past memory worth resurfacing on Home.
///
/// An entry from today's month and day in an earlier year always wins — that
/// is the resonance the feature exists for. Failing that, a day-seeded pick
/// from entries old enough to feel like the past. The seed is the day number,
/// so the choice is stable for a whole day instead of reshuffling on every
/// view update.
enum ResurfacedMemory {
  /// Entries newer than this are still recent enough to be on the Diary tab's
  /// first screen; resurfacing them would not feel like remembering.
  static let fallbackMinimumAgeInDays = 30

  struct Pick: Equatable {
    var entry: DiaryEntry
    /// Set only when the entry falls on today's month and day in an earlier year.
    var yearsAgo: Int?
  }

  static func pick(
    from entries: [DiaryEntry],
    on date: Date = Date(),
    calendar: Calendar = .current
  ) -> Pick? {
    let today = calendar.dateComponents([.year, .month, .day], from: date)
    guard let todayYear = today.year else { return nil }

    let onThisDay = entries.filter { entry in
      let components = calendar.dateComponents([.year, .month, .day], from: entry.entryDate)
      guard let year = components.year else { return false }
      return components.month == today.month && components.day == today.day && year < todayYear
    }

    // Several years may share the date; the most recent one is the least stale.
    if let match = onThisDay.max(by: { $0.entryDate < $1.entryDate }) {
      let years = calendar.dateComponents([.year], from: match.entryDate, to: date).year ?? 1
      return Pick(entry: match, yearsAgo: max(years, 1))
    }

    guard
      let cutoff = calendar.date(byAdding: .day, value: -fallbackMinimumAgeInDays, to: date)
    else {
      return nil
    }

    // Sorted so the seed maps to the same entry regardless of store ordering.
    let pool = entries
      .filter { $0.entryDate < cutoff }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    guard !pool.isEmpty else { return nil }

    let seed = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    return Pick(entry: pool[seed % pool.count], yearsAgo: nil)
  }

  static func heading(for pick: Pick) -> String {
    guard let years = pick.yearsAgo else { return "A while ago" }
    return years == 1 ? "One year ago today" : "\(years) years ago today"
  }
}
