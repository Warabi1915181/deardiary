//
//  ContentView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 21/03/2026.
//

import SwiftUI

struct ViewWithBackdrop<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      Color(.backdrop).ignoresSafeArea()
      content
    }
    // Handwritten body is the app default; SF only appears where a view
    // explicitly opts into .system.
    .font(.regular)
  }
}

struct ContentView: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    TabView {
      Tab("Home", systemImage: "house") {
        ViewWithBackdrop {
          HomeView()
        }
      }
      Tab("Diary", systemImage: "book.closed") {
        NavigationStack {
          ViewWithBackdrop {
            DiaryView(store: environment.diaryStore)
          }
        }
      }
      Tab("Our List", systemImage: "list.bullet") {
        NavigationStack {
          ViewWithBackdrop {
            ToDoView(store: environment.toDoStore)
          }
        }
      }
      Tab("Settings", systemImage: "gear") {
        NavigationStack {
          ViewWithBackdrop {
            SettingsMenuView()
          }
        }
      }
    }
    .tint(Color("RomanceForeground"))
    .overlay(alignment: .top) {
      syncBanner
    }
  }

  @ViewBuilder
  private var syncBanner: some View {
    switch environment.syncCoordinator.partnerSyncStatus {
    case .syncing:
      syncBannerLabel("Syncing...")
    case .offlineChangesSaved:
      syncBannerLabel("Offline changes saved")
    case .syncFailed:
      syncBannerLabel("Couldn't sync. Will retry.")
    default:
      EmptyView()
    }
  }

  private func syncBannerLabel(_ text: String) -> some View {
    Text(text)
      .font(.regular(size: 14))
      .foregroundStyle(Color("RomanceForeground"))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        Capsule()
          .fill(Color("RomanceBackground"))
      )
      .padding(.top, 8)
  }
}

#Preview {
  ContentView()
    .environment(AppEnvironment())
}
