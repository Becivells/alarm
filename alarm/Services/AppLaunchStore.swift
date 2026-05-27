//
//  AppLaunchStore.swift
//  alarm
//

import Foundation

/// 应用启动时执行一次（显示悬浮窗、启动调度器等）
@MainActor
enum AppLaunchStore {
    private static var didRun = false
    static var setup: (() -> Void)?

    static func runIfNeeded() {
        guard !didRun, let setup else { return }
        didRun = true
        setup()
    }
}
