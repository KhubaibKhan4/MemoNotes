//
//  ReminderScheduler.swift
//  Notes
//

import Foundation
import SwiftData
import UserNotifications
import UIKit

/// Schedules local notifications for todo and note reminders.
///
/// Reminders only fire when the "Enable Notifications" setting is on and the
/// system permission is granted. `resync` rebuilds every pending notification
/// from the database, so it is safe to call whenever things may be out of step
/// (app launch, after an import, after turning notifications back on).
@MainActor
enum ReminderScheduler {

    static let settingKey = "EnableNotifications"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: settingKey)
    }

    private static var center: UNUserNotificationCenter { .current() }

    // MARK: - Permission

    /// Makes sure reminders can be delivered, asking for permission if it hasn't been asked yet.
    /// Turns the in-app setting on when permission is granted. Returns `false` if the user said no.
    static func ensurePermission() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        let granted: Bool
        switch status {
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .notDetermined:
            granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            granted = false
        }
        if granted {
            UserDefaults.standard.set(true, forKey: settingKey)
        }
        return granted
    }

    // MARK: - Todos

    static func schedule(_ todo: TodoItem) {
        cancel(todoID: todo.id)
        guard isEnabled, todo.hasReminder, !todo.isCompleted,
              let due = todo.dueDate, due > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = todo.title
        content.body = todo.notes.isEmpty ? "Task due now" : todo.notes
        content.sound = .default
        add(id: todoIdentifier(todo.id), content: content, at: due)
    }

    static func cancel(todoID: String) {
        center.removePendingNotificationRequests(withIdentifiers: [todoIdentifier(todoID)])
    }

    // MARK: - Notes

    static func schedule(_ note: NotesItem) {
        cancel(noteID: note.id)
        guard isEnabled, let date = note.reminderDate, date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = note.title
        content.body = note.desc.isEmpty ? "Note reminder" : String(note.desc.prefix(150))
        content.sound = .default
        add(id: noteIdentifier(note.id), content: content, at: date)
    }

    static func cancel(noteID: String) {
        center.removePendingNotificationRequests(withIdentifiers: [noteIdentifier(noteID)])
    }

    // MARK: - All

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Clears pending notifications and schedules every future reminder again.
    static func resync(context: ModelContext) {
        cancelAll()
        guard isEnabled else { return }
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<NotesItem>())) ?? []
        todos.forEach(schedule)
        notes.forEach(schedule)
    }

    // MARK: - Helpers

    private static func todoIdentifier(_ id: String) -> String { "todo.\(id)" }
    private static func noteIdentifier(_ id: String) -> String { "note.\(id)" }

    private static func add(id: String, content: UNMutableNotificationContent, at date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

/// Shows reminder banners even while the app is in the foreground.
final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

extension Date {
    /// The start of the next hour — a sensible default for new due dates.
    static var nextHour: Date {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .hour, for: Date())?.start ?? Date()
        return calendar.date(byAdding: .hour, value: 1, to: start) ?? Date().addingTimeInterval(3600)
    }
}
