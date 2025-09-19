//
//  Cluck_GamepackApp.swift
//  Cluck Gamepack
//
//  Created by Serhii Babchuk on 16.09.2025.
//

import SwiftUI

@main
struct Cluck_GamepackApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            AppEntryPoint()
        }
    }
}
