//
//  FunnelOverlayView.swift
//  alarm
//

import SwiftUI

extension ReminderCountdown {
    /// 圆环进度刷新间隔（秒）；中央倒计时始终 1 秒
    static func progressRefreshInterval(remainingSeconds: TimeInterval) -> TimeInterval {
        if remainingSeconds > 120 { return 10 }
        if remainingSeconds > 60 { return 5 }
        return 1
    }

    static func quantizedProgress(_ progress: Double) -> Double {
        (progress * 1000).rounded() / 1000
    }
}

struct CircularProgressRing: View {
    let progress: Double
    let isFiring: Bool
    let palette: OverlayColorPalette
    let lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var trackColor: Color {
        if palette.usesSystemAppearance {
            return Color.primary.opacity(0.12)
        }
        return palette.trackRing.swiftUIColor
    }

    private var progressColor: Color {
        if palette.usesSystemAppearance {
            return isFiring ? .orange : .accentColor
        }
        return isFiring
            ? palette.progressRingFiring.swiftUIColor
            : palette.progressRing.swiftUIColor
    }
}

struct CountdownTimeLabel: View, Equatable {
    let display: String
    let isFiring: Bool
    let intervalMinutes: Int
    let pulseScale: CGFloat
    let palette: OverlayColorPalette

    static func == (lhs: CountdownTimeLabel, rhs: CountdownTimeLabel) -> Bool {
        lhs.display == rhs.display
            && lhs.isFiring == rhs.isFiring
            && lhs.intervalMinutes == rhs.intervalMinutes
            && lhs.pulseScale == rhs.pulseScale
            && lhs.palette == rhs.palette
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(display)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(countdownColor)
                .shadow(
                    color: palette.countdownShadow ? .black.opacity(0.45) : .clear,
                    radius: 1,
                    x: 0,
                    y: 0.5
                )

            Text("\(intervalMinutes) 分钟")
                .font(.caption2)
                .foregroundStyle(subtitleColor)
        }
        .scaleEffect(pulseScale)
    }

    private var countdownColor: Color {
        if palette.usesSystemAppearance {
            return isFiring ? .orange : .primary
        }
        return isFiring
            ? palette.countdownFiring.swiftUIColor
            : palette.countdown.swiftUIColor
    }

    private var subtitleColor: Color {
        if palette.usesSystemAppearance {
            return .secondary
        }
        return palette.subtitle.swiftUIColor
    }
}

struct FunnelOverlayView: View {
    @Bindable var scheduler: ReminderScheduler

    private var isFiring: Bool { scheduler.phase == .firing }
    private var palette: OverlayColorPalette { scheduler.settings.resolvedOverlayPalette }

    var body: some View {
        VStack(spacing: 10) {
            countdownRing
                .frame(width: 118, height: 118)

            HStack(spacing: 6) {
                overlayButton(scheduler.isPaused ? "继续" : "暂停") {
                    if scheduler.isPaused {
                        scheduler.resume()
                    } else {
                        scheduler.pause()
                    }
                }
                overlayButton("跳过") {
                    scheduler.skip()
                }
                overlayButton("设置") {
                    NotificationCenter.default.post(name: .openReminderSettings, object: nil)
                }
            }
        }
        .frame(width: 140)
        .padding(10)
    }

    @ViewBuilder
    private var countdownRing: some View {
        if scheduler.isPaused || !scheduler.settings.enabled {
            ZStack {
                CircularProgressRing(progress: 0, isFiring: isFiring, palette: palette)
                staticStatusLabel
            }
        } else {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let now = context.date
                let display = ReminderCountdown.remainingDisplay(
                    at: now,
                    nextFireDate: scheduler.nextFireDate
                )

                ZStack {
                    progressRingLayer

                    EquatableView(
                        content: CountdownTimeLabel(
                            display: display,
                            isFiring: isFiring,
                            intervalMinutes: scheduler.settings.intervalMinutes,
                            pulseScale: reminderPulseScale(at: now),
                            palette: palette
                        )
                    )
                }
            }
        }
    }

    /// 圆环按剩余时间自适应刷新；与 1Hz 倒计时文字分离
    @ViewBuilder
    private var progressRingLayer: some View {
        let remaining = ReminderCountdown.remainingSeconds(nextFireDate: scheduler.nextFireDate)
        let interval = ReminderCountdown.progressRefreshInterval(remainingSeconds: remaining)

        TimelineView(.periodic(from: .now, by: interval)) { context in
            let progress = ReminderCountdown.quantizedProgress(
                ReminderCountdown.cycleProgress(
                    at: context.date,
                    phase: scheduler.phase,
                    enabled: scheduler.settings.enabled,
                    nextFireDate: scheduler.nextFireDate,
                    intervalSeconds: scheduler.settings.intervalSeconds
                )
            )
            CircularProgressRing(progress: progress, isFiring: isFiring, palette: palette)
        }
    }

    private func reminderPulseScale(at date: Date) -> CGFloat {
        guard isFiring else { return 1 }
        return Int(date.timeIntervalSince1970) % 2 == 0 ? 1.05 : 1
    }

    @ViewBuilder
    private var staticStatusLabel: some View {
        let color = palette.usesSystemAppearance
            ? Color.secondary
            : palette.statusLabel.swiftUIColor

        if scheduler.isPaused {
            Text("已暂停")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        } else {
            Text("未启用")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private var controlLabelColor: Color {
        if palette.usesSystemAppearance {
            return isFiring ? .orange : .secondary
        }
        return isFiring
            ? palette.controlLabelFiring.swiftUIColor
            : palette.controlLabel.swiftUIColor
    }

    private var controlAccentColor: Color {
        if palette.usesSystemAppearance {
            return isFiring ? .orange : .accentColor
        }
        return isFiring
            ? palette.controlLabelFiring.swiftUIColor
            : palette.controlLabel.swiftUIColor
    }

    private func overlayButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(controlLabelColor)
        }
        .buttonStyle(.plain)
        .tint(controlAccentColor)
    }
}

#Preview {
    FunnelOverlayView(scheduler: ReminderScheduler())
}
