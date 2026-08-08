import SwiftUI
import UIKit

/// The page ends in margin. A ruled aside for the resurfaced memory, and one
/// quiet line for waiting ideas — neither is a Card, so neither competes with
/// the snapshot and notes above.
struct ResurfacedMemoryWhisper: View {
  let pick: ResurfacedMemory.Pick

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(ResurfacedMemory.heading(for: pick))
        .font(.metadata)
        .foregroundStyle(Color("InkMuted"))
      Text(handwritten: pick.entry.title)
        .font(.regularItalic(size: 24))
        .foregroundStyle(Color("RomanceForeground"))
        .multilineTextAlignment(.leading)
      Text(pick.entry.entryDate.formatted(date: .abbreviated, time: .omitted))
        .font(.metadata)
        .foregroundStyle(Color("InkMuted"))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 12)
    .overlay(alignment: .leading) {
      // True 1px hairline — the documented exception to the 4pt grid.
      Rectangle()
        .fill(Color("PlumForeground").opacity(0.35))
        .frame(width: 1)
    }
  }
}

struct IdeasWaitingRow: View {
  let count: Int

  private var label: String {
    count == 1 ? "1 idea waiting" : "\(count) ideas waiting"
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.body)
        .foregroundStyle(Color("InkMuted"))
      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color("InkMuted"))
      Spacer(minLength: 0)
    }
    .frame(height: 44)
    .contentShape(Rectangle())
  }
}

struct HomeView: View {
  @Environment(AppEnvironment.self) private var environment
  @Binding var selectedTab: AppTab

  private var anniversaryAnchorDay: Date {
    environment.coupleSpaceStore.datingStartDay
  }

  /// Next calendar occurrence of anchor month/day (local TZ), inclusive of today.
  private var anniversaryDate: Date {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    let m = calendar.component(.month, from: anniversaryAnchorDay)
    let d = calendar.component(.day, from: anniversaryAnchorDay)
    let year = calendar.component(.year, from: Date())
    var dc = DateComponents(year: year, month: m, day: d)
    guard var candidate = calendar.date(from: dc) else {
      return todayStart
    }
    if calendar.startOfDay(for: candidate) < todayStart {
      dc.year = year + 1
      candidate = calendar.date(from: dc) ?? candidate
    }
    return calendar.startOfDay(for: candidate)
  }

  private var daysUntilAnniversary: Int {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    return calendar.dateComponents([.day], from: todayStart, to: anniversaryDate).day ?? 0
  }

  private var daysTogether: Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: anniversaryAnchorDay)
    let todayStart = calendar.startOfDay(for: Date())
    return max(calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0, 0)
  }

  /// The single soonest upcoming moment worth surfacing: whichever of the
  /// nearest user-created milestone or the auto-derived special-number
  /// moment lands first. Never both, never a list — see AutoMilestone.swift.
  private var nextMilestoneCandidate: HomeMilestone? {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    let milestoneStore = environment.milestoneStore

    let nearestUserMilestone = milestoneStore.milestones
      .map { ($0, milestoneStore.nextOccurrence(of: $0)) }
      .filter { calendar.startOfDay(for: $0.1) >= todayStart }
      .min { $0.1 < $1.1 }

    let autoMoment = AutoMilestone.nextMoment(datingStartDay: anniversaryAnchorDay)

    func milestone(icon: String, title: String, date: Date) -> HomeMilestone {
      HomeMilestone(icon: icon, title: title, date: date, daysUntil: daysUntil(date))
    }

    switch (nearestUserMilestone, autoMoment) {
    case let (userMilestone?, auto?):
      if userMilestone.1 <= auto.date {
        return milestone(icon: userMilestone.0.icon, title: userMilestone.0.title, date: userMilestone.1)
      } else {
        return milestone(icon: "sparkles", title: auto.label, date: auto.date)
      }
    case let (userMilestone?, nil):
      return milestone(icon: userMilestone.0.icon, title: userMilestone.0.title, date: userMilestone.1)
    case let (nil, auto?):
      return milestone(icon: "sparkles", title: auto.label, date: auto.date)
    case (nil, nil):
      return nil
    }
  }

  private var resurfacedPick: ResurfacedMemory.Pick? {
    ResurfacedMemory.pick(from: environment.diaryStore.entries)
  }

  private func daysUntil(_ date: Date) -> Int {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    return calendar.dateComponents([.day], from: todayStart, to: calendar.startOfDay(for: date)).day ?? 0
  }

  private var content: HomeContent {
    let latestEntry = environment.diaryStore.latestEntry
    return HomeContent(
      anniversaryDate: anniversaryDate,
      daysTogether: daysTogether,
      daysUntilAnniversary: daysUntilAnniversary,
      latestEntry: latestEntry,
      latestPhotoURL: latestEntry?.photos.first.map { environment.diaryStore.photoURL(for: $0) },
      milestone: nextMilestoneCandidate,
      resurfaced: resurfacedPick,
      ideasWaiting: environment.toDoStore.activeItemCount
    )
  }

  var body: some View {
    ScrollView {
      HomeScrapbookLayout(content: content, selectedTab: $selectedTab)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    .scrollIndicators(.hidden)
  }
}
