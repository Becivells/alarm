//
//  FlashOverlayController.swift
//  alarm
//

import AppKit
import Foundation

enum BreathingOpacity {
    static func value(
        at now: Date,
        startedAt: Date,
        duration: TimeInterval,
        breathPeriod: TimeInterval = 2.2,
        peakOpacity: Float = 0.22
    ) -> Float {
        let elapsed = now.timeIntervalSince(startedAt)
        guard elapsed >= 0, elapsed < duration else { return 0 }

        let fadeWindow: TimeInterval = 0.8
        var envelope = 1.0
        if elapsed < fadeWindow {
            envelope = elapsed / fadeWindow
        } else if elapsed > duration - fadeWindow {
            envelope = max(0, (duration - elapsed) / fadeWindow)
        }

        let phase = (elapsed / breathPeriod) * 2 * .pi
        let wave = (sin(phase) + 1) / 2
        return Float(wave) * peakOpacity * Float(envelope)
    }
}

/// 全屏单层 CALayer 呼吸灯，避免 SwiftUI 全屏离屏缓冲
final class BreathingOverlayNSView: NSView {
    private let tintLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        tintLayer.backgroundColor = NSColor.systemOrange.cgColor
        tintLayer.opacity = 0
        layer?.addSublayer(tintLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        tintLayer.frame = bounds
    }

    func setBreathOpacity(_ opacity: Float) {
        tintLayer.opacity = opacity
    }
}

@MainActor
final class FlashOverlayController {
    private var panel: NSPanel?
    private var overlayView: BreathingOverlayNSView?
    private var startedAt: Date?
    private var duration: TimeInterval = 9
    private var scheduledTimers: [Timer] = []
    private var teardownTask: Task<Void, Never>?

    func flash(duration: TimeInterval = 9) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        tearDownPanel()

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hasShadow = false

        let overlay = BreathingOverlayNSView(frame: frame)
        panel.contentView = overlay

        self.panel = panel
        self.overlayView = overlay
        self.startedAt = Date()
        self.duration = duration

        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        updateBreathOpacity(at: Date())
        scheduleBreathUpdates()

        teardownTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.3))
            tearDownPanel()
        }
    }

    func close() {
        tearDownPanel()
    }

    private func scheduleBreathUpdates() {
        let steps = max(1, Int(duration.rounded(.up)))
        for second in 1..<steps {
            let delay = TimeInterval(second)
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startedAt = self.startedAt else { return }
                    self.updateBreathOpacity(at: startedAt.addingTimeInterval(delay))
                }
            }
            scheduledTimers.append(timer)
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func updateBreathOpacity(at now: Date) {
        guard let overlayView, let startedAt else { return }
        let opacity = BreathingOpacity.value(at: now, startedAt: startedAt, duration: duration)
        overlayView.setBreathOpacity(opacity)
    }

    private func tearDownPanel() {
        teardownTask?.cancel()
        teardownTask = nil
        scheduledTimers.forEach { $0.invalidate() }
        scheduledTimers.removeAll()
        startedAt = nil
        overlayView = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }
}
