import CloudKit
import SwiftUI

/// Bridges UIKit share-acceptance callbacks into SwiftUI.
///
/// CloudKit share metadata is delivered on the scene (not the app delegate) for
/// scene-based apps, and can arrive at cold launch before SwiftUI wires up its
/// handler. This broker buffers such metadata until the handler is assigned.
final class ShareAcceptanceCoordinator {
  static let shared = ShareAcceptanceCoordinator()

  private var pendingMetadata: CKShare.Metadata?

  var onAccept: ((CKShare.Metadata) -> Void)? {
    didSet {
      guard let onAccept, let metadata = pendingMetadata else { return }
      pendingMetadata = nil
      onAccept(metadata)
    }
  }

  func accept(_ metadata: CKShare.Metadata) {
    if let onAccept {
      onAccept(metadata)
    } else {
      // Handler not wired up yet (e.g. cold launch) — buffer until it is.
      pendingMetadata = metadata
    }
  }
}

/// Receives CloudKit share acceptance. For scene-based apps (all SwiftUI apps),
/// the system calls these scene methods — NOT the app delegate equivalents.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
  func scene(
    _: UIScene,
    willConnectTo _: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Cold launch triggered by accepting an invite.
    if let metadata = connectionOptions.cloudKitShareMetadata {
      ShareAcceptanceCoordinator.shared.accept(metadata)
    }
  }

  func windowScene(
    _: UIWindowScene,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
  ) {
    // App already running when the invite is accepted.
    ShareAcceptanceCoordinator.shared.accept(cloudKitShareMetadata)
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options _: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: nil,
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}

@main
struct Dear_DiaryApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var environment = AppEnvironment()

  init() {
    let segmented = UISegmentedControl.appearance()
    segmented.backgroundColor = UIColor(named: "SurfaceMuted")
    segmented.selectedSegmentTintColor = UIColor(named: "RomanceBackground")
    segmented.setTitleTextAttributes(
      [.foregroundColor: UIColor(named: "RomanceForeground") ?? .label],
      for: .selected
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(environment)
        .font(.body)
        .task {
          configureShareAcceptanceHandler()
        }
    }
  }

  private func configureShareAcceptanceHandler() {
    ShareAcceptanceCoordinator.shared.onAccept = { metadata in
      Task { @MainActor in
        do {
          try await environment.syncCoordinator.handleAcceptedShare(metadata)
        } catch {
          environment.syncCoordinator.reportSyncFailure(error.localizedDescription)
        }
      }
    }
  }
}
