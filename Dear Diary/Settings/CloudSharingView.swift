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

  func updateUIViewController(_: UICloudSharingController, context _: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator: NSObject, UICloudSharingControllerDelegate {
    func cloudSharingControllerDidSaveShare(_: UICloudSharingController) {}

    func cloudSharingControllerDidStopSharing(_: UICloudSharingController) {}

    func cloudSharingController(_: UICloudSharingController, failedToSaveShareWithError _: Error) {}

    func itemTitle(for _: UICloudSharingController) -> String? {
      "Dear Diary"
    }
  }
}
