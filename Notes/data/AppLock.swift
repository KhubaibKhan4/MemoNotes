//
//  AppLock.swift
//  Notes
//

import SwiftUI
import LocalAuthentication

/// How long the app may stay in the background before it locks again.
enum AppLockTimeout: Double, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .immediately: String(localized: "Immediately")
        case .oneMinute: String(localized: "After 1 minute")
        case .fiveMinutes: String(localized: "After 5 minutes")
        case .fifteenMinutes: String(localized: "After 15 minutes")
        }
    }
}

/// Locks the app behind Face ID / Touch ID / Optic ID, falling back to the device passcode.
@MainActor
final class AppLockManager: ObservableObject {

    static let enabledKey = "AppLockEnabled"
    static let timeoutKey = "AppLockTimeout"

    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false

    private var backgroundedAt: Date?
    /// Show the Face ID prompt by itself only on launch and when returning from the
    /// background — not after the person cancels it, or they could never dismiss it.
    private var shouldPromptAutomatically: Bool

    init() {
        // Start locked so nothing shows before the person unlocks.
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        // Keep the widgets' copy of the setting in step.
        SharedStore.setAppLockEnabled(enabled)
        isLocked = enabled
        shouldPromptAutomatically = enabled
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    private var timeout: TimeInterval {
        UserDefaults.standard.double(forKey: Self.timeoutKey)
    }

    /// Call on every scene phase change.
    func sceneChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            if backgroundedAt == nil { backgroundedAt = Date() }
        case .active:
            if isEnabled, let backgroundedAt, Date().timeIntervalSince(backgroundedAt) >= timeout {
                isLocked = true
                shouldPromptAutomatically = true
            }
            backgroundedAt = nil
            if isLocked && shouldPromptAutomatically {
                shouldPromptAutomatically = false
                unlock()
            }
        default:
            // .inactive also happens while the Face ID prompt is up; don't lock for that.
            break
        }
    }

    func unlock() {
        guard isLocked, !isAuthenticating else { return }
        guard isEnabled else {
            isLocked = false
            return
        }
        isAuthenticating = true
        Task {
            let success = await Self.authenticate(reason: String(localized: "Unlock your notes"))
            isAuthenticating = false
            if success {
                isLocked = false
            }
        }
    }

    // MARK: - Helpers

    /// Whether this device can lock the app (biometrics or a passcode is set up).
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode", for labels.
    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "Passcode")
        }
    }

    static var methodSymbol: String {
        switch methodName {
        case "Face ID": "faceid"
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        default: "lock"
        }
    }

    /// Asks for Face ID / Touch ID / Optic ID, or the device passcode.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Full-screen cover shown while the app is locked, and in the app switcher.
struct LockScreenView: View {
    @EnvironmentObject private var lock: AppLockManager
    /// Privacy cover only (app switcher): no unlock button.
    var showsUnlockButton = true

    var body: some View {
        VStack(spacing: 20) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)

            if showsUnlockButton {
                VStack(spacing: 6) {
                    Text("Notes Locked")
                        .font(.title2).bold()
                    Text("Unlock with \(AppLockManager.methodName) to see your notes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    lock.unlock()
                } label: {
                    Label("Unlock", systemImage: AppLockManager.methodSymbol)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(lock.isAuthenticating)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
