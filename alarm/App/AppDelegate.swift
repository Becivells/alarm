//
//  AppDelegate.swift
//  alarm
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: .openReminderSettings,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                SettingsWindowBridge.open()
            }
        }

        // 设置窗尚未出现时先注册；稍后重试以确保悬浮窗在启动时显示
        Task { @MainActor in
            await Task.yield()
            AppLaunchStore.runIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }
}
