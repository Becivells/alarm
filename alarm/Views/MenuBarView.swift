//
//  MenuBarView.swift
//  alarm
//

import SwiftUI

struct MenuBarView: View {
    @Bindable var scheduler: ReminderScheduler
    @State private var remainingText = "--:--"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("剩余 \(remainingText)")
                .font(.headline.monospacedDigit())

            if scheduler.isPaused {
                Button("继续") { scheduler.resume() }
            } else {
                Button("暂停") { scheduler.pause() }
            }

            Button("打开设置") {
                SettingsWindowBridge.open()
            }

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .onAppear {
            remainingText = scheduler.remainingDisplay
        }
    }
}
