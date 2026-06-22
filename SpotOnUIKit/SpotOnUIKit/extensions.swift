import UIKit

// MARK: UIColor
extension UIColor {
    // App palette (matches the SwiftUI crystal theme).
    static let crystalBlue = UIColor(hex: "5BA8D9")
    static let crystalMint = UIColor(hex: "52C9A8")
    static let crystalGold = UIColor(hex: "D4A840")

    convenience init(hex: String) {
        var rgb: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: .alphanumerics.inverted)).scanHexInt64(&rgb)
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

// MARK: UIView
extension UIView {
    func roundedGlass(radius: CGFloat = 16) {
        layer.cornerRadius = radius
        layer.borderWidth = 1
        layer.borderColor = UIColor.crystalBlue.withAlphaComponent(0.25).cgColor
    }
}
