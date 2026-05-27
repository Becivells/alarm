//
//  FunnelOverlayController.swift
//  alarm
//

import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class FunnelOverlayController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FunnelOverlayView>?
    private var scheduler: ReminderScheduler?

    func attach(scheduler: ReminderScheduler) {
        let needsRebuild = self.scheduler !== scheduler || hostingView == nil
        self.scheduler = scheduler
        if needsRebuild, hostingView != nil {
            rebuildContent()
        }
    }

    func show() {
        guard let scheduler else { return }
        if panel == nil {
            createPanel(scheduler: scheduler)
        }
        positionBottomRight()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
        hostingView = nil
        scheduler = nil
    }

    private func rebuildContent() {
        guard let scheduler, let hostingView else { return }
        hostingView.rootView = FunnelOverlayView(scheduler: scheduler)
    }

    private func createPanel(scheduler: ReminderScheduler) {
        let contentRect = NSRect(x: 0, y: 0, width: 160, height: 200)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let hostingView = NSHostingView(rootView: FunnelOverlayView(scheduler: scheduler))
        hostingView.frame = contentRect
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
    }

    private func positionBottomRight() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - 24,
            y: visible.minY + 24
        )
        panel.setFrameOrigin(origin)
    }
}
