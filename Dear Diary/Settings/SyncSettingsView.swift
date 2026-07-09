import CloudKit
import SwiftUI

struct SyncSettingsView: View {
  @Environment(AppEnvironment.self) private var environment
  @State private var isShowingShareSheet = false
  @State private var isShowingLeaveConfirmation = false
  @State private var actionErrorMessage: String?

  private var syncCoordinator: CloudKitSyncCoordinator {
    environment.syncCoordinator
  }

  var body: some View {
    Form {
      Section("iCloud") {
        LabeledContent("Status") {
          Text(syncCoordinator.accountAvailability.title)
            .foregroundStyle(iCloudStatusColor)
        }

        Text(syncCoordinator.accountAvailability.message)
          .font(.regular(size: 14))
          .foregroundStyle(Color("SecondaryForeground"))

        Button {
          Task {
            await syncCoordinator.refreshAccountStatus()
          }
        } label: {
          if syncCoordinator.isRefreshingAccountStatus {
            ProgressView()
          } else {
            Text("Check iCloud Status")
          }
        }
        .disabled(syncCoordinator.isRefreshingAccountStatus)
      }

      Section("Partner Sync") {
        LabeledContent("Sync Status") {
          Text(syncCoordinator.partnerSyncStatus.title)
            .foregroundStyle(partnerSyncColor)
        }

        Text(syncCoordinator.partnerSyncStatus.message)
          .font(.regular(size: 14))
          .foregroundStyle(Color("SecondaryForeground"))

        if !environment.coupleSpaceStore.isSynced {
          Button("Invite Partner") {
            Task {
              await invitePartner()
            }
          }
          .disabled(!syncCoordinator.accountAvailability.isAvailable)
        } else if syncCoordinator.pendingShare != nil {
          Button("Share Invitation") {
            isShowingShareSheet = true
          }
        }

        if environment.coupleSpaceStore.isSynced {
          Button("Leave Shared Diary", role: .destructive) {
            isShowingLeaveConfirmation = true
          }
        }

        if let actionErrorMessage {
          Text(actionErrorMessage)
            .font(.regular(size: 14))
            .foregroundStyle(.red)
        }
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
      await syncCoordinator.refreshAccountStatus()
    }
    .sheet(isPresented: $isShowingShareSheet) {
      if
        let share = syncCoordinator.pendingShare,
        let container = syncCoordinator.pendingShareContainer
      {
        CloudSharingView(container: container, share: share)
      }
    }
    .sheet(isPresented: Binding(
      get: { syncCoordinator.showPartnerMergePrompt },
      set: { syncCoordinator.showPartnerMergePrompt = $0 }
    )) {
      PartnerMergePromptView(
        onMerge: {
          Task {
            await syncCoordinator.mergeLocalDataIntoSharedDiary()
          }
        },
        onKeepSeparate: {
          syncCoordinator.keepLocalDataSeparate()
        }
      )
    }
    .confirmationDialog(
      "Leave Shared Diary?",
      isPresented: $isShowingLeaveConfirmation,
      titleVisibility: .visible
    ) {
      Button("Leave Shared Diary", role: .destructive) {
        Task {
          await syncCoordinator.leaveSharedDiary()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Sync will stop on this device, but your local copy of the diary will stay here.")
    }
  }

  private var iCloudStatusColor: Color {
    syncCoordinator.accountAvailability.isAvailable
      ? Color("SageForeground")
      : Color("SecondaryForeground")
  }

  private var partnerSyncColor: Color {
    switch syncCoordinator.partnerSyncStatus {
    case .syncFailed:
      return .red
    case .notSynced:
      return Color("SecondaryForeground")
    default:
      return Color("SageForeground")
    }
  }

  private func invitePartner() async {
    actionErrorMessage = nil
    do {
      try await syncCoordinator.invitePartner()
      if syncCoordinator.pendingShare != nil {
        isShowingShareSheet = true
      }
    } catch {
      actionErrorMessage = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    SyncSettingsView()
      .environment(AppEnvironment())
  }
}
