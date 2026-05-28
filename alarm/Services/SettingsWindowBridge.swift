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

    /// 设置窗口（含已关闭但尚未销毁的）
    static var anchorWindow: NSWindow? {
        NSApp.windows.first { window in
            guard window.canBecomeMain, !window.isKind(of: NSPanel.self) else { return false }
            if window.identifier?.rawValue == windowID { return true }
            return window.title == "提醒设置"
        }
    }

    /// 当前正在显示、可作为 Sheet 附着的设置窗（避免为弹窗强行打开设置页）
    static var visibleAnchorWindow: NSWindow? {
        guard let window = anchorWindow, window.isVisible else { return nil }
        return window
    }
}
