import SwiftUI
import UIKit

struct AnniversaryCard: View {
  var anniversaryDate: Date
  var numberOfDays: Int

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: "heart.fill")
            .foregroundColor(Color("HeartRose"))
            .font(.system(size: 16))
          Text("Our Anniversary")
            .fontWeight(.semibold)
        }
        Text("\(numberOfDays)")
          .font(.fancy(size: 38))
        Text("days left")
          .fontWeight(.semibold)
        Text(anniversaryDate.formatted(date: .abbreviated, time: .omitted))
          .font(.regular)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 16)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color("Backdrop"))
      )
    }
  }
}

struct LatestMemoryCard: View {
  let entry: DiaryEntry
  let photoURL: URL?

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 4) {
          Image(systemName: "book.closed")
            .foregroundStyle(Color("RomanceForeground"))
          Text("Latest Memory")
            .fontWeight(.semibold)
        }

        Text(entry.title)
          .font(.bold(size: 22))
          .foregroundStyle(Color("RomanceForeground"))

        if !entry.body.isEmpty {
          Text(entry.body)
            .font(.regular(size: 16))
            .foregroundStyle(Color("RomanceForeground"))
            .lineLimit(3)
        }

        if let photoURL, let image = UIImage(contentsOfFile: photoURL.path) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
          .font(.regular(size: 14))
          .foregroundStyle(Color("PlumForeground"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct HomeView: View {
  @Environment(AppEnvironment.self) private var environment

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

  var body: some View {
    VStack(spacing: 16) {
      AnniversaryCard(anniversaryDate: anniversaryDate, numberOfDays: daysUntilAnniversary)
      if let latestEntry = environment.diaryStore.latestEntry {
        LatestMemoryCard(
          entry: latestEntry,
          photoURL: latestEntry.photos.first.map { environment.diaryStore.photoURL(for: $0) }
        )
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical)
  }
}
