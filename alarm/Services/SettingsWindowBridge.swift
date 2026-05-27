//
//  SettingsWindowBridge.swift
//  alarm
//

import AppKit
import SwiftUI

/// 在菜单栏/悬浮窗与 SwiftUI `openWindow` 之间桥接，用于关闭设置窗后再次打开
@MainActor
enum SettingsWindowBridge {
    static let windowID = "settings"

    static var openHandler: (() -> Void)?

    static func register(openWindow: OpenWindowAction) {
        openHandler = {
            openWindow(id: windowID)
        }
    }

    static func open() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = anchorWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        openHandler?()
    }

    /// 可作为 Sheet 弹窗附着的窗口（设置窗优先）
    static var anchorWindow: NSWindow? {
        NSApp.windows.first { window in
            guard window.canBecomeMain, !window.isKind(of: NSPanel.self) else { return false }
            if window.identifier?.rawValue == windowID { return true }
            return window.title == "提醒设置"
        }
    }
}
