import CloudKit
import SwiftUI
import UIKit

struct CloudSharingView: UIViewControllerRepresentable {
  let container: CKContainer
  let share: CKShare

  func makeUIViewController(context: Context) -> UICloudSharingController {
    let controller = UICloudSharingController(share: share, container: container)
    controller.availablePermissions = [.allowReadWrite, .allowPrivate]
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator: NSObject, UICloudSharingControllerDelegate {
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

    func itemTitle(for csc: UICloudSharingController) -> String? {
      "Dear Diary"
    }
  }
}
