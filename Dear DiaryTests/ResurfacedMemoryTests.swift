@testable import Dear_Diary
import Foundation
import Testing

struct ResurfacedMemoryTests {
  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }

  private func entry(
    _ title: String,
    on entryDate: Date,
    id: UUID = UUID()
  ) -> DiaryEntry {
    DiaryEntry(
      id: id,
      coupleSpaceID: nil,
      title: title,
      body: "",
      entryDate: entryDate,
      mood: nil,
      tags: [],
      photos: [],
      isFavorite: false,
      createdAt: entryDate,
      updatedAt: entryDate,
      deletedAt: nil,
      modifiedByDeviceID: "test",
      version: 1
    )
  }

  @Test func prefersEntryFromTodayInAnEarlierYear() throws {
    let today = date(2026, 8, 1)
    let entries = [
      entry("Yesterday", on: date(2026, 7, 31)),
      entry("Tainan", on: date(2025, 8, 1)),
      entry("Old but wrong day", on: date(2024, 3, 3)),
    ]

    let pick = try #require(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar))
    #expect(pick.entry.title == "Tainan")
    #expect(pick.yearsAgo == 1)
    #expect(ResurfacedMemory.heading(for: pick) == "One year ago today")
  }

  @Test func picksMostRecentWhenSeveralYearsShareTheDay() throws {
    let today = date(2026, 8, 1)
    let entries = [
      entry("Three years ago", on: date(2023, 8, 1)),
      entry("Two years ago", on: date(2024, 8, 1)),
    ]

    let pick = try #require(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar))
    #expect(pick.entry.title == "Two years ago")
    #expect(pick.yearsAgo == 2)
    #expect(ResurfacedMemory.heading(for: pick) == "2 years ago today")
  }

  @Test func todaysOwnEntryIsNotResurfaced() throws {
    let today = date(2026, 8, 1)
    let entries = [
      entry("Written today", on: today),
      entry("Long ago", on: date(2025, 1, 4)),
    ]

    let pick = try #require(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar))
    #expect(pick.entry.title == "Long ago")
    #expect(pick.yearsAgo == nil)
  }

  @Test func leapDayEntryMatchesOnlyOnALeapDay() throws {
    let leapEntry = entry("Leap day", on: date(2024, 2, 29))
    let older = entry("Fallback", on: date(2023, 5, 5))

    let onLeapDay = try #require(
      ResurfacedMemory.pick(from: [leapEntry, older], on: date(2028, 2, 29), calendar: utcCalendar)
    )
    #expect(onLeapDay.entry.title == "Leap day")
    #expect(onLeapDay.yearsAgo == 4)

    // 28 Feb in a non-leap year must not absorb the 29th.
    let onFeb28 = try #require(
      ResurfacedMemory.pick(from: [leapEntry, older], on: date(2027, 2, 28), calendar: utcCalendar)
    )
    #expect(onFeb28.yearsAgo == nil)
  }

  @Test func fallsBackToAnEntryOlderThanTheMinimumAge() throws {
    let today = date(2026, 8, 1)
    let entries = [
      entry("Two weeks ago", on: date(2026, 7, 18)),
      entry("Last winter", on: date(2025, 12, 25)),
    ]

    let pick = try #require(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar))
    #expect(pick.entry.title == "Last winter")
    #expect(pick.yearsAgo == nil)
    #expect(ResurfacedMemory.heading(for: pick) == "A while ago")
  }

  @Test func fallbackIsStableWithinADayAndIndependentOfOrdering() throws {
    let today = date(2026, 8, 1)
    let entries = (0 ..< 5).map { offset in
      entry("Entry \(offset)", on: date(2025, 1, 1 + offset))
    }

    let first = try #require(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar))
    let again = try #require(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar))
    let shuffled = try #require(
      ResurfacedMemory.pick(from: entries.reversed(), on: today, calendar: utcCalendar)
    )

    #expect(first == again)
    #expect(first == shuffled)
  }

  @Test func returnsNothingWhenEverythingIsTooRecent() {
    let today = date(2026, 8, 1)
    let entries = [
      entry("Three days ago", on: date(2026, 7, 29)),
      entry("Last week", on: date(2026, 7, 25)),
    ]

    #expect(ResurfacedMemory.pick(from: entries, on: today, calendar: utcCalendar) == nil)
  }

  @Test func returnsNothingWithNoEntries() {
    #expect(ResurfacedMemory.pick(from: [], on: date(2026, 8, 1), calendar: utcCalendar) == nil)
  }
}
