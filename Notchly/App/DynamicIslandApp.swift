//
//  DynamicIslandApp.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import SwiftUI

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
