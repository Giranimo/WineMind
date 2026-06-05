import Foundation
import Security
import CryptoKit
import UIKit
import ImageIO

/// Security-critical helpers: Keychain-backed identifiers, cryptographic hashing, EXIF stripping.
actor SecurityService {
    static let shared = SecurityService()

    private let service = "com.winemind.app"
    private let contributorIDKey = "publicContributorID"

    // MARK: - Public Contributor ID (Anonymous)

    /// A stable, opaque, locally-generated UUID used to group a user's anonymous public
    /// ratings together. NOT derived from Apple ID — cannot be reversed to identify the user.
    /// Stored in Keychain so it survives uninstalls only if iCloud Keychain syncs it.
    func contributorID() throws -> String {
        if let existing = readKeychain(key: contributorIDKey) {
            return existing
        }
        let new = UUID().uuidString
        try writeKeychain(key: contributorIDKey, value: new)
        return new
    }

    /// Rotate the contributor ID — used when the user opts out of contributions or deletes account.
    /// New ratings will be attributed to a fresh ID; prior public ratings stay anonymous because
    /// the old ID is gone from this device and from the user's record.
    func rotateContributorID() throws -> String {
        let new = UUID().uuidString
        try writeKeychain(key: contributorIDKey, value: new)
        return new
    }

    func deleteContributorID() {
        deleteKeychain(key: contributorIDKey)
    }

    // MARK: - Cryptographic Hashing

    /// SHA-256 hex digest. Use when you genuinely need a one-way hash.
    /// Not used for the contributor ID — that's an opaque UUID, which is stronger.
    static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Image Sanitization

    /// Strip EXIF, GPS, and other metadata from an image before upload.
    /// Wine label photos often have GPS coordinates from where the bottle was photographed —
    /// users don't expect that to be shared.
    static func strippedJPEGData(from image: UIImage, quality: CGFloat = 0.8) -> Data? {
        guard let cgImage = image.cgImage else {
            return image.jpegData(compressionQuality: quality)
        }

        // Re-encode without any metadata
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.jpeg" as CFString,
            1, nil
        ) else {
            return image.jpegData(compressionQuality: quality)
        }

        // Empty properties dictionary — drops EXIF, GPS, TIFF, IPTC, etc.
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return image.jpegData(compressionQuality: quality)
        }

        return mutableData as Data
    }

    // MARK: - Keychain

    private func writeKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecurityError.encodingFailed
        }

        deleteKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainWriteFailed(status: status)
        }
    }

    private func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func deleteKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum SecurityError: LocalizedError {
    case encodingFailed
    case keychainWriteFailed(status: OSStatus)
    case keychainReadFailed
    case keychainDeleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Could not encode the value"
        case .keychainWriteFailed(let status): return "Keychain write failed (\(status))"
        case .keychainReadFailed: return "Keychain read failed"
        case .keychainDeleteFailed(let status): return "Keychain delete failed (\(status))"
        }
    }
}
