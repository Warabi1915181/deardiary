import CloudKit
import Foundation

enum CloudKitAccountAvailability: Equatable {
  case unknown
  case available
  case noAccount
  case restricted
  case couldNotDetermine
  case temporarilyUnavailable
  case error(String)

  init(_ status: CKAccountStatus) {
    switch status {
    case .available:
      self = .available
    case .noAccount:
      self = .noAccount
    case .restricted:
      self = .restricted
    case .couldNotDetermine:
      self = .couldNotDetermine
    case .temporarilyUnavailable:
      self = .temporarilyUnavailable
    @unknown default:
      self = .couldNotDetermine
    }
  }

  var title: String {
    switch self {
    case .unknown:
      return "Not Checked"
    case .available:
      return "iCloud Available"
    case .noAccount:
      return "No iCloud Account"
    case .restricted:
      return "iCloud Restricted"
    case .couldNotDetermine:
      return "Could Not Determine"
    case .temporarilyUnavailable:
      return "Temporarily Unavailable"
    case .error:
      return "Check Failed"
    }
  }

  var message: String {
    switch self {
    case .unknown:
      return "Open this screen to check whether iCloud is available for sync."
    case .available:
      return "This device can use iCloud for Dear Diary sync."
    case .noAccount:
      return "Sign in to iCloud on this device before enabling partner sync."
    case .restricted:
      return "iCloud access is restricted on this device."
    case .couldNotDetermine:
      return "Dear Diary could not determine iCloud availability."
    case .temporarilyUnavailable:
      return "iCloud is temporarily unavailable. Try again later."
    case let .error(message):
      return message
    }
  }

  var isAvailable: Bool {
    self == .available
  }
}

@MainActor
@Observable
final class CloudKitSyncService {
  nonisolated static let containerIdentifier = "iCloud.dev.mochiholic.Dear-Diary"

  private(set) var accountAvailability: CloudKitAccountAvailability = .unknown
  private(set) var isRefreshingAccountStatus = false

  private let container: CKContainer

  init(container: CKContainer = CKContainer(identifier: CloudKitSyncService.containerIdentifier)) {
    self.container = container
  }

  func refreshAccountStatus() async {
    isRefreshingAccountStatus = true
    defer { isRefreshingAccountStatus = false }

    do {
      let status = try await container.accountStatus()
      accountAvailability = CloudKitAccountAvailability(status)
    } catch {
      accountAvailability = .error(error.localizedDescription)
    }
  }
}
