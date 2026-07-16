@testable import Dear_Diary
import Foundation
import Testing

struct AutoMilestoneTests {
  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  @Test func picksSoonestFutureDayThreshold() throws {
    let calendar = utcCalendar
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    // Just shy of the 100-day mark.
    let now = calendar.date(byAdding: .day, value: 99, to: start)!

    let moment = try #require(AutoMilestone.nextMoment(datingStartDay: start, now: now, calendar: calendar))
    let expectedDate = calendar.date(byAdding: .day, value: 100, to: start)!
    #expect(moment.date == expectedDate)
    #expect(moment.label == "100 days together")
  }

  @Test func skipsPastThresholds() throws {
    let calendar = utcCalendar
    let start = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
    // Just past the 1000-day mark; next curated threshold is 1500.
    let now = calendar.date(byAdding: .day, value: 1001, to: start)!

    let moment = try #require(AutoMilestone.nextMoment(datingStartDay: start, now: now, calendar: calendar))
    let expectedDate = calendar.date(byAdding: .day, value: 1500, to: start)!
    #expect(moment.date == expectedDate)
    #expect(moment.label == "1500 days together")
  }

  @Test func boundaryAtExactlyAThresholdDayMovesToNextThreshold() throws {
    let calendar = utcCalendar
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    // Exactly on the 100-day mark: strictly-future comparison should skip it.
    let now = calendar.date(byAdding: .day, value: 100, to: start)!

    let moment = try #require(AutoMilestone.nextMoment(datingStartDay: start, now: now, calendar: calendar))
    let expectedDate = calendar.date(byAdding: .day, value: 250, to: start)!
    #expect(moment.date == expectedDate)
    #expect(moment.label == "250 days together")
  }

  @Test func returnsNilWhenEveryThresholdHasPassed() throws {
    let calendar = utcCalendar
    let start = calendar.date(from: DateComponents(year: 1980, month: 1, day: 1))!
    let now = calendar.date(byAdding: .day, value: 20000, to: start)!

    let moment = AutoMilestone.nextMoment(datingStartDay: start, now: now, calendar: calendar)
    #expect(moment == nil)
  }

  @Test func minuteThresholdCanWinWhenSoonerThanNextDayThreshold() throws {
    let calendar = utcCalendar
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    // 1,000,000 minutes is ~694.44 days out, between the 500- and 750-day marks.
    let now = calendar.date(byAdding: .day, value: 690, to: start)!

    let moment = try #require(AutoMilestone.nextMoment(datingStartDay: start, now: now, calendar: calendar))
    #expect(moment.label == "1,000,000 minutes together")
  }
}
