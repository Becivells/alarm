//
//  MenuBarRootView.swift
//  alarm
//

import SwiftUI

/// 菜单栏常驻视图：注册 `openWindow`，保证设置窗关闭后仍可打开
struct MenuBarRootView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var scheduler: ReminderScheduler
    let ensureLaunch: () -> Void

    var body: some View {
        MenuBarView(scheduler: scheduler)
            .onAppear {
                SettingsWindowBridge.register(openWindow: openWindow)
                ensureLaunch()
            }
    }
}
