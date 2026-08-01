//
//  ContentView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 21/03/2026.
//

import SwiftUI

struct ViewWithBackdrop<Content: View>: View {
  var atmosphere: BackdropAtmosphere
  @ViewBuilder var content: Content

  init(
    atmosphere: BackdropAtmosphere = .none,
    @ViewBuilder content: () -> Content
  ) {
    self.atmosphere = atmosphere
    self.content = content()
  }

  var body: some View {
    ZStack {
      Color(.backdrop).ignoresSafeArea()
      if atmosphere == .candlelightHome {
        CandlelightAtmosphere()
          .ignoresSafeArea()
      }
      content
    }
    // Handwritten body is the app default; SF only appears where a view
    // explicitly opts into .system.
    .font(.body)
  }
}

/// The app's four surfaces. Named so one screen can send the reader to
/// another — Home's ideas line opens Our List.
enum AppTab: Hashable {
  case home
  case diary
  case ourList
  case settings
}

struct ContentView: View {
  @Environment(AppEnvironment.self) private var environment
  @State private var selectedTab: AppTab = .home

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Home", systemImage: "house", value: AppTab.home) {
        NavigationStack {
          ViewWithBackdrop(atmosphere: .candlelightHome) {
            HomeView(selectedTab: $selectedTab)
          }
        }
      }
      Tab("Diary", systemImage: "book.closed", value: AppTab.diary) {
        NavigationStack {
          ViewWithBackdrop {
            DiaryView(store: environment.diaryStore)
          }
        }
      }
      Tab("Our List", systemImage: "list.bullet", value: AppTab.ourList) {
        NavigationStack {
          ViewWithBackdrop {
            ToDoView(store: environment.toDoStore, diaryStore: environment.diaryStore)
          }
        }
      }
      Tab("Settings", systemImage: "gear", value: AppTab.settings) {
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
      .font(.metadata)
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
