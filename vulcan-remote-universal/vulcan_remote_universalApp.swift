//
//  vulcan_remote_universalApp.swift
//  vulcan-remote-universal
//
//  Created by HIBIKI CUBE on 2023/01/17.
//

import SwiftUI

@main
struct vulcan_remote_universalApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
              .environmentObject(CoreBluetoothViewModel())
        }
    }
}
