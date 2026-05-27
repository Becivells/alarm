//
//  SettingsView.swift
//  alarm
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var scheduler: ReminderScheduler
    @State private var selectedPresetIndex: Int = 1
    @State private var remainingDisplay = "--:--"

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("周期") {
                Toggle("启用提醒", isOn: $scheduler.settings.enabled)
                    .onChange(of: scheduler.settings.enabled) { _, _ in
                        scheduler.applySettingsAndRestart()
                        refreshRemaining()
                    }

                Picker("预设间隔", selection: $selectedPresetIndex) {
                    ForEach(ReminderSettings.presetOptions.indices, id: \.self) { index in
                        let option = ReminderSettings.presetOptions[index]
                        Text(option.label).tag(index)
                    }
                }
                .onChange(of: selectedPresetIndex) { _, newValue in
                    scheduler.settings.intervalSeconds = ReminderSettings.presetOptions[newValue].seconds
                    syncPresetIndex()
                    scheduler.applySettingsAndRestart()
                    refreshRemaining()
                }

                Stepper(
                    "自定义：\(scheduler.settings.intervalMinutes) 分钟",
                    value: $scheduler.settings.intervalMinutes,
                    in: 1...180
                )
                .onChange(of: scheduler.settings.intervalMinutes) { _, _ in
                    syncPresetIndex()
                    scheduler.applySettingsAndRestart()
                    refreshRemaining()
                }
            }

            Section("提醒方式") {
                Toggle("弹窗", isOn: $scheduler.settings.alertPopup)
                Toggle("语音", isOn: $scheduler.settings.alertSpeech)
                Toggle("屏幕柔光闪烁", isOn: $scheduler.settings.alertFlash)

                TextField("语音内容", text: $scheduler.settings.speechText)
            }

            Section("状态") {
                LabeledContent("剩余时间") {
                    Text(remainingDisplay)
                        .font(.body.monospacedDigit())
                }
                if let next = scheduler.nextFireDate {
                    LabeledContent("下次提醒") {
                        Text(next.formatted(date: .omitted, time: .shortened))
                    }
                }
                LabeledContent("运行状态") {
                    Text(statusText)
                }
            }

            Section("控制") {
                HStack {
                    if scheduler.isPaused {
                        Button("继续") {
                            scheduler.resume()
                            refreshRemaining()
                        }
                    } else {
                        Button("暂停") {
                            scheduler.pause()
                            refreshRemaining()
                        }
                    }
                    Button("跳过本次") {
                        scheduler.skip()
                        refreshRemaining()
                    }
                    Button("重置倒计时") {
                        scheduler.resetCountdown()
                        refreshRemaining()
                    }
                }

                Button("测试提醒") {
                    scheduler.testReminder()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 480)
        .onAppear {
            SettingsWindowBridge.register(openWindow: openWindow)
            syncPresetIndex()
            refreshRemaining()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshRemaining()
        }
    }

    private var statusText: String {
        if scheduler.phase == .firing { return "提醒中" }
        if scheduler.isPaused { return "已暂停" }
        if !scheduler.settings.enabled { return "未启用" }
        return "运行中"
    }

    private func refreshRemaining() {
        remainingDisplay = scheduler.remainingDisplay
    }

    private func syncPresetIndex() {
        let seconds = scheduler.settings.intervalSeconds
        if let index = ReminderSettings.presetOptions.firstIndex(where: { $0.seconds == seconds }) {
            selectedPresetIndex = index
        }
    }
}

#Preview {
    SettingsView(scheduler: ReminderScheduler())
}
