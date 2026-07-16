import Foundation

/// A restrained, ephemeral "next special number" moment derived from the
/// couple's `datingStartDay`. This is deliberately NOT a persisted
/// `Milestone` — it is recomputed fresh every time, never editable, and
/// never surfaced as a list. DESIGN.md's anti-gamification principle rules
/// out a badge wall: the app shows the single next moment worth noticing,
/// nothing more.
enum AutoMilestone {
  struct Moment: Equatable {
    var date: Date
    var label: String
  }

  /// Curated, ascending day-count thresholds. Frequent early (100, 250,
  /// 500...) when a new number arrives often and worth celebrating, spacing
  /// out over the years so the app never nags with an endless list.
  private static let dayThresholds = [
    100, 250, 500, 750, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 7500, 10000,
  ]

  /// A single whimsical round-minute figure, kept singular by design: one
  /// playful surprise (about 694 days in) sitting alongside the day-count
  /// milestones, not a second parallel counting system.
  private static let minuteThreshold = 1_000_000

  /// Locale-independent so the label reads the same on every device
  /// regardless of the user's region settings.
  private static let minuteNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = ","
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  /// Returns the single soonest special-number moment strictly after `now`,
  /// or `nil` once every curated threshold has already passed.
  static func nextMoment(
    datingStartDay: Date,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> Moment? {
    let startOfDatingDay = calendar.startOfDay(for: datingStartDay)

    var candidates: [Moment] = []

    for days in dayThresholds {
      guard let date = calendar.date(byAdding: .day, value: days, to: startOfDatingDay) else { continue }
      guard date > now else { continue }
      candidates.append(Moment(date: date, label: "\(days) days together"))
    }

    if
      let minuteDate = calendar.date(byAdding: .minute, value: minuteThreshold, to: datingStartDay),
      minuteDate > now
    {
      let formattedMinutes = minuteNumberFormatter.string(from: NSNumber(value: minuteThreshold))
        ?? "\(minuteThreshold)"
      candidates.append(Moment(date: minuteDate, label: "\(formattedMinutes) minutes together"))
    }

    return candidates.min { $0.date < $1.date }
  }
}
