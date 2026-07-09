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
  }
}

struct ContentView: View {
  @EnvironmentObject private var environment: AppEnvironment

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
      .foregroundStyle(Color("PrimaryForeground"))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        Capsule()
          .fill(Color("PrimaryBackground"))
      )
      .padding(.top, 8)
  }
}

#Preview {
  ContentView()
    .environmentObject(AppEnvironment())
}
