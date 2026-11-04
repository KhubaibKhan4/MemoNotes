//
//  Haptics.swift
//  Notes
//

import UIKit

/// Haptic feedback that respects the "Enable Haptics" setting.
enum Haptics {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "EnableHaptics") as? Bool ?? true
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
