//
//  SwiftUI_BLE_ProjectApp.swift
//  SwiftUI-BLE-Project
//
//  Created by kazuya ito on 2021/02/02.
//

import SwiftUI

@main
struct VULCAN_Remote: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(CoreBluetoothViewModel())
        }
    }
}
