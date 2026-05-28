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
    private var speechStopRequested = false
    private var speechRetryCount = 0
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
        speechStopRequested = true
        speechSynthesizer?.stopSpeaking(at: .immediate)
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

        // 先播完语音再弹窗，避免模态对话框抢占音频（外接音响上易截断）
        if settings.alertSpeech {
            await speak()
        }

        if settings.alertPopup {
            await showPopupAsync()
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

        speechRetryCount = 0
        speechStopRequested = false

        let synthesizer = speechSynthesizer ?? AVSpeechSynthesizer()
        speechSynthesizer = synthesizer

        if synthesizer.isSpeaking {
            speechStopRequested = true
            synthesizer.stopSpeaking(at: .immediate)
            speechStopRequested = false
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.12

        var didResume = false
        let maxWait = max(20, Double(text.count) * 0.35 + 8)
        let speakStarted = ContinuousClock.now

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let finish: @MainActor () -> Void = { [weak self] in
                guard !didResume else { return }
                didResume = true
                self?.speechDelegate = nil
                continuation.resume()
            }

            let retrySpeak: @MainActor () -> Void = { [weak self] in
                guard let self, !self.speechStopRequested, self.speechRetryCount < 1 else {
                    finish()
                    return
                }
                self.speechRetryCount += 1
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !self.speechStopRequested else {
                        finish()
                        return
                    }
                    synthesizer.speak(utterance)
                }
            }

            let delegate = SpeechSynthesisDelegate(
                onComplete: { spokenText, synthesizer in
                    Task { @MainActor [weak self] in
                        guard let self else {
                            finish()
                            return
                        }
                        let elapsed = speakStarted.duration(to: .now)
                        let expectedMin = max(0.65, Double(spokenText.count) * 0.1)
                        if elapsed < .seconds(expectedMin * 0.55), !self.speechStopRequested, self.speechRetryCount < 1 {
                            retrySpeak()
                            return
                        }
                        try? await Task.sleep(for: .seconds(Self.playbackDrainDelay(for: spokenText, synthesizer: synthesizer)))
                        finish()
                    }
                },
                onCancel: { _, _ in
                    Task { @MainActor [weak self] in
                        guard let self else {
                            finish()
                            return
                        }
                        if self.speechStopRequested {
                            finish()
                            return
                        }
                        retrySpeak()
                    }
                }
            )
            speechDelegate = delegate
            synthesizer.delegate = delegate

            synthesizer.speak(utterance)

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(maxWait))
                finish()
            }
        }
    }

    /// 合成结束到外接设备播完之间的缓冲（USB/HDMI 常有额外延迟）
    private static func playbackDrainDelay(for text: String, synthesizer: AVSpeechSynthesizer) -> TimeInterval {
        let base: TimeInterval = 0.4
        let perChar = 0.015
        let speakingPad = synthesizer.isSpeaking ? 0.25 : 0
        return min(2.5, base + Double(text.count) * perChar + speakingPad)
    }

    private func showPopupAsync() async {
        let alert = NSAlert()
        alert.messageText = "提醒"
        alert.informativeText = settings.speechText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.addButton(withTitle: "延后 5 分钟")

        let response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
            if let window = SettingsWindowBridge.visibleAnchorWindow {
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
    private let onComplete: (String, AVSpeechSynthesizer) -> Void
    private let onCancel: (String, AVSpeechSynthesizer) -> Void

    init(
        onComplete: @escaping (String, AVSpeechSynthesizer) -> Void,
        onCancel: @escaping (String, AVSpeechSynthesizer) -> Void
    ) {
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in onComplete(text, synthesizer) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in onCancel(text, synthesizer) }
    }
}
