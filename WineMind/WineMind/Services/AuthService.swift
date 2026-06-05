import Foundation
import AuthenticationServices
import CloudKit
import SwiftUI

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var isSignedIn: Bool = false
    @Published var userIdentifier: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @Published var errorMessage: String?

    private let userDefaultsKey = "winemind.appleUserID"
    private let userNameKey = "winemind.userName"

    override init() {
        super.init()
        loadStoredCredentials()
        // Deliberately do NOT touch CloudKit here. CloudKit is only accessed from
        // consent-gated paths (sync / recommendations / contribution / the Settings
        // status row), so an iCloud/CloudKit misconfiguration can never crash launch.
    }

    // MARK: - Stored Credentials

    private func loadStoredCredentials() {
        if let stored = UserDefaults.standard.string(forKey: userDefaultsKey), !stored.isEmpty {
            userIdentifier = stored
            userName = UserDefaults.standard.string(forKey: userNameKey)
            isSignedIn = true
            verifyAppleIDCredentialState(userID: stored)
        }
    }

    private func verifyAppleIDCredentialState(userID: String) {
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .authorized:
                    self.isSignedIn = true
                case .revoked, .notFound:
                    self.signOut()
                case .transferred:
                    self.signOut()
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Apple Sign In Flow

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                userIdentifier = userID
                UserDefaults.standard.set(userID, forKey: userDefaultsKey)

                if let fullName = credential.fullName,
                   let given = fullName.givenName {
                    let name = [given, fullName.familyName ?? ""].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    userName = name
                    UserDefaults.standard.set(name, forKey: userNameKey)
                }

                userEmail = credential.email
                isSignedIn = true
                errorMessage = nil
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        userIdentifier = nil
        userName = nil
        userEmail = nil
        isSignedIn = false
    }

    // MARK: - CloudKit Status

    func checkCloudKitStatus() async {
        do {
            let status = try await CloudKitService.shared.accountStatus()
            cloudKitStatus = status
        } catch {
            cloudKitStatus = .couldNotDetermine
            errorMessage = "iCloud check failed: \(error.localizedDescription)"
        }
    }

    var cloudKitStatusMessage: String {
        switch cloudKitStatus {
        case .available: return "iCloud connected"
        case .noAccount: return "Please sign in to iCloud in Settings to sync your wines"
        case .restricted: return "iCloud is restricted on this device"
        case .couldNotDetermine: return "Checking iCloud status…"
        case .temporarilyUnavailable: return "iCloud temporarily unavailable"
        @unknown default: return "Unknown iCloud status"
        }
    }
}
