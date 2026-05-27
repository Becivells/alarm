//
//  ReminderSettings.swift
//  alarm
//

import Foundation

struct ReminderSettings: Codable, Equatable {
    var intervalSeconds: TimeInterval = 10 * 60
    var enabled: Bool = true
    var alertPopup: Bool = true
    var alertSpeech: Bool = true
    var alertFlash: Bool = true
    var speechText: String = "该休息了"

    static let presetOptions: [(label: String, seconds: TimeInterval)] = [
        ("5 分钟", 5 * 60),
        ("10 分钟", 10 * 60),
        ("15 分钟", 15 * 60),
        ("25 分钟", 25 * 60),
        ("45 分钟", 45 * 60),
        ("60 分钟", 60 * 60),
    ]

    var intervalMinutes: Int {
        get { Int(intervalSeconds / 60) }
        set { intervalSeconds = TimeInterval(max(1, newValue)) * 60 }
    }
}
