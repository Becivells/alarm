//
//  SettingsStore.swift
//  alarm
//

import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaultsKey = "reminderSettings"
    private let defaults = UserDefaults.standard

    private init() {}

    func load() -> ReminderSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data)
        else {
            return ReminderSettings()
        }
        return settings
    }

    func save(_ settings: ReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
