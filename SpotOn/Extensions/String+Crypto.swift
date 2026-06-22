import Foundation
import CryptoKit

extension String {
    var sha256Hash: String {
        let hash = SHA256.hash(data: Data(utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var nonce = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            bytes.forEach { byte in
                guard remaining > 0, byte < charset.count else { return }
                nonce.append(charset[Int(byte)])
                remaining -= 1
            }
        }
        return nonce
    }
}
