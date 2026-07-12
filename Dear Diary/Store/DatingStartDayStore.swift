import Foundation
import SwiftUI

/// Shared persistence + date rules for “dating start day”. Survives launches; same key app-wide.
enum DatingStartDayStore {
  /// `UserDefaults` / `@AppStorage` value is `Date.timeIntervalSince1970`.
  static let appStorageKey = "datingStartDay.since1970"

  /// Default when the key is missing (first launch).
  static var appStorageDefaultInterval: TimeInterval {
    Date().timeIntervalSince1970
  }

  /// Inclusive bounds; `endDate` is end of today (local TZ).
  static func allowedDateRange(referenceNow: Date = Date()) -> ClosedRange<Date> {
    let calendar = Calendar.current
    let startDate =
      calendar.date(byAdding: .year, value: -200, to: referenceNow) ?? Date.distantPast
    let todayStart = calendar.startOfDay(for: referenceNow)
    let endDate =
      calendar.date(bySettingHour: 23, minute: 59, second: 59, of: todayStart) ?? todayStart
    return startDate ... endDate
  }

  static func clamp(_ date: Date, in range: ClosedRange<Date>? = nil) -> Date {
    let r = range ?? allowedDateRange()
    return min(max(date, r.lowerBound), r.upperBound)
  }

  /// Calendar-safe start day from persisted storage.
  static func datingStartDate(storedInterval: TimeInterval) -> Date {
    clamp(Date(timeIntervalSince1970: storedInterval))
  }

  /// For `@AppStorage(DatingStartDayStore.appStorageKey) var interval: Double`.
  static func dateBinding(storedInterval: Binding<TimeInterval>, onChange: ((Date) -> Void)? = nil)
    -> Binding<Date>
  {
    Binding(
      get: { datingStartDate(storedInterval: storedInterval.wrappedValue) },
      set: {
        storedInterval.wrappedValue = $0.timeIntervalSince1970
        onChange?($0)
      },
    )
  }
}
