//
//  WidiCoreBluetoothDemoApp.swift
//  WidiCoreBluetoothDemo
//
//  Created by Maximilian Maksutovic on 1/13/24.
//

import SwiftUI

@main
struct WidiCoreBluetoothDemoApp: App {
	let bluetooth = BluetoothManager.shared
	
    var body: some Scene {
        WindowGroup {
            ContentView()
				.environmentObject(bluetooth)
        }
    }
}
