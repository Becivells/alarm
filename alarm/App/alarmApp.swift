//
//  alarmApp.swift
//  alarm
//

import SwiftUI

@main
struct alarmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var scheduler = ReminderScheduler()
    @State private var funnelController = FunnelOverlayController()
    @State private var flashController = FlashOverlayController()

    var body: some Scene {
        WindowGroup("提醒设置", id: SettingsWindowBridge.windowID) {
            SettingsView(scheduler: scheduler)
                .onAppear {
                    registerLaunchSetup()
                }
        }
        .defaultSize(width: 420, height: 520)

        MenuBarExtra {
            MenuBarRootView(scheduler: scheduler, ensureLaunch: registerLaunchSetup)
        } label: {
            Image("Logo")
                .frame(width: 18, height: 18)
        }
    }

    private func registerLaunchSetup() {
        AppLaunchStore.setup = launchSetup
        AppLaunchStore.runIfNeeded()
    }

    private func launchSetup() {
        scheduler.flashController = flashController
        funnelController.attach(scheduler: scheduler)
        funnelController.show()
        scheduler.start()

        appDelegate.onTerminate = {
            scheduler.shutdown()
            funnelController.close()
            flashController.close()
        }
    }
}
