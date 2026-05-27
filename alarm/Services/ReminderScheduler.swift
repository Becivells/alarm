//
//  ReminderScheduler.swift
//  alarm
//

import AppKit
import AVFoundation
import Foundation
import Observation

enum ReminderPhase: Equatable {
    case idle
    case firing
}

enum ReminderCountdown {
    static func remainingSeconds(at now: Date = Date(), nextFireDate: Date?) -> TimeInterval {
        guard let nextFireDate else { return 0 }
        return max(0, nextFireDate.timeIntervalSince(now))
    }

    static func remainingDisplay(at now: Date = Date(), nextFireDate: Date?) -> String {
        let total = Int(remainingSeconds(at: now, nextFireDate: nextFireDate).rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func cycleProgress(
        at now: Date = Date(),
        phase: ReminderPhase,
        enabled: Bool,
        nextFireDate: Date?,
        intervalSeconds: TimeInterval
    ) -> Double {
        if phase == .firing { return 1 }
        guard enabled, nextFireDate != nil else { return 0 }
        guard intervalSeconds > 0 else { return 0 }
        let remaining = remainingSeconds(at: now, nextFireDate: nextFireDate)
        let elapsed = intervalSeconds - remaining
        return min(1, max(0, elapsed / intervalSeconds))
    }
}

@Observable
@MainActor
final class ReminderScheduler {
    var settings: ReminderSettings {
        didSet {
            guard settings != oldValue else { return }
            store.save(settings)
        }
    }

    var nextFireDate: Date?
    var isPaused: Bool = false
    var phase: ReminderPhase = .idle

    weak var flashController: FlashOverlayController?

    private let store = SettingsStore.shared
    private var fireTimer: Timer?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var speechDelegate: SpeechSynthesisDelegate?
    private var wakeObserver: NSObjectProtocol?

    init() {
        settings = store.load()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleNextFire()
            }
        }
    }

    var remainingSeconds: TimeInterval {
        ReminderCountdown.remainingSeconds(nextFireDate: nextFireDate)
    }

    var cycleProgress: Double {
        ReminderCountdown.cycleProgress(
            phase: phase,
            enabled: settings.enabled,
            nextFireDate: nextFireDate,
            intervalSeconds: settings.intervalSeconds
        )
    }

    var remainingDisplay: String {
        ReminderCountdown.remainingDisplay(nextFireDate: nextFireDate)
    }

    func start() {
        isPaused = false
        if nextFireDate == nil {
            reschedule(from: Date())
        } else {
            scheduleNextFire()
        }
    }

    func pause() {
        isPaused = true
        cancelFireTimer()
    }

    func resume() {
        isPaused = false
        if nextFireDate == nil {
            reschedule(from: Date())
        } else {
            scheduleNextFire()
        }
    }

    func skip() {
        reschedule(from: Date())
        if phase == .firing {
            endFiring()
        }
    }

    func resetCountdown() {
        reschedule(from: Date())
    }

    func snooze(seconds: TimeInterval) {
        nextFireDate = Date().addingTimeInterval(seconds)
        endFiring()
        scheduleNextFire()
    }

    func testReminder() {
        Task { await fireReminder() }
    }

    func applySettingsAndRestart() {
        store.save(settings)
        if settings.enabled {
            reschedule(from: Date())
        } else {
            nextFireDate = nil
            cancelFireTimer()
        }
    }

    func shutdown() {
        cancelFireTimer()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
        speechDelegate = nil
    }

    private func cancelFireTimer() {
        fireTimer?.invalidate()
        fireTimer = nil
    }

    private func scheduleNextFire() {
        cancelFireTimer()
        guard settings.enabled, !isPaused, phase == .idle, let nextFireDate else { return }

        let interval = max(0.05, nextFireDate.timeIntervalSinceNow)
        fireTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fireReminder()
            }
        }
        if let fireTimer {
            RunLoop.main.add(fireTimer, forMode: .common)
        }
    }

    private func reschedule(from date: Date) {
        nextFireDate = date.addingTimeInterval(settings.intervalSeconds)
        scheduleNextFire()
    }

    private func fireReminder() async {
        guard phase != .firing else { return }
        cancelFireTimer()
        phase = .firing

        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        NSApp.activate(ignoringOtherApps: true)

        if settings.alertFlash {
            flashController?.flash()
            await Task.yield()
        }

        let speechTask: Task<Void, Never>? = settings.alertSpeech
            ? Task { await speak() }
            : nil

        if settings.alertPopup {
            await showPopupAsync()
        }

        if let speechTask {
            await speechTask.value
        }

        reschedule(from: Date())

        try? await Task.sleep(for: .seconds(3))
        endFiring()
    }

    private func endFiring() {
        phase = .idle
        scheduleNextFire()
    }

    private func speak() async {
        let text = settings.speechText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let synthesizer = speechSynthesizer ?? AVSpeechSynthesizer()
        speechSynthesizer = synthesizer

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        var didResume = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let finish: @MainActor () -> Void = { [weak self] in
                guard !didResume else { return }
                didResume = true
                self?.speechDelegate = nil
                self?.speechSynthesizer = nil
                continuation.resume()
            }

            let delegate = SpeechSynthesisDelegate { finish() }
            speechDelegate = delegate
            synthesizer.delegate = delegate

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                ?? AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            synthesizer.speak(utterance)

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                finish()
            }
        }
    }

    private func showPopupAsync() async {
        let alert = NSAlert()
        alert.messageText = "提醒"
        alert.informativeText = settings.speechText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.addButton(withTitle: "延后 5 分钟")

        var window = SettingsWindowBridge.anchorWindow
        if window == nil {
            SettingsWindowBridge.open()
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(50))
                if let found = SettingsWindowBridge.anchorWindow {
                    window = found
                    break
                }
            }
        }

        let response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
            if let window {
                alert.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                continuation.resume(returning: alert.runModal())
            }
        }

        if response == .alertSecondButtonReturn {
            snooze(seconds: 5 * 60)
        }
    }
}

private final class SpeechSynthesisDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onComplete() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in onComplete() }
    }
}
