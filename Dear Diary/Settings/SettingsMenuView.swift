//
//  SettingsMenuView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 01/05/2026.
//

import SwiftUI
import UIKit

struct SettingsMenuView: View {
  var body: some View {
    VStack(spacing: 16) {
      Text("Settings")
        .font(.regularItalic(size: 48))
      List {
        Section(header: Text("General")) {
          NavigationLink(destination: DatingSettingsView()) {
            Text("Dating Start Day")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        Section(header: Text("Sync")) {
          NavigationLink(destination: SyncSettingsView()) {
            Text("Sync with Partner")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Color("Backdrop"))
      .modifier(LightModeDoubleListShadow())
    }
  }
}

private struct LightModeDoubleListShadow: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    if colorScheme == .light {
      content
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
    } else {
      content
    }
  }
}

#Preview {
	ViewWithBackdrop {
		SettingsMenuView()
	}
}
