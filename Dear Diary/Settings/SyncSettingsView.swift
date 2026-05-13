import SwiftUI

struct SyncSettingsView: View {
  @StateObject private var syncService = CloudKitSyncService()

  var body: some View {
    Form {
      Section("iCloud") {
        LabeledContent("Status") {
          Text(syncService.accountAvailability.title)
            .foregroundStyle(statusColor)
        }

        Text(syncService.accountAvailability.message)
          .font(.regular(size: 14))
          .foregroundStyle(Color("SecondaryForeground"))

        Button {
          Task {
            await syncService.refreshAccountStatus()
          }
        } label: {
          if syncService.isRefreshingAccountStatus {
            ProgressView()
          } else {
            Text("Check iCloud Status")
          }
        }
        .disabled(syncService.isRefreshingAccountStatus)
      }

      Section("Partner Sync") {
        Button("Invite Partner") {}
          .disabled(true)

        Button("Leave Shared Diary", role: .destructive) {}
          .disabled(true)

        Text("Partner invitations will be enabled after CoupleSpace and CKShare records are added.")
          .font(.regular(size: 14))
          .foregroundStyle(Color("SecondaryForeground"))
      }

      Section("Privacy") {
        Text("Your data syncs through iCloud.")
          .font(.regular(size: 14))
          .foregroundStyle(Color("SecondaryForeground"))
      }
    }
    .navigationTitle("Sync")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await syncService.refreshAccountStatus()
    }
  }

  private var statusColor: Color {
    syncService.accountAvailability.isAvailable ? Color("SageForeground") : Color("SecondaryForeground")
  }
}

#Preview {
  NavigationStack {
    SyncSettingsView()
  }
}
