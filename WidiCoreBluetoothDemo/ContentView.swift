import SwiftUI

struct ContentView: View {
	@EnvironmentObject var bluetooth: BluetoothManager

	var body: some View {
		VStack {
			HStack {
				Text(bluetooth.isScanning ? "Scanning For Devices" : "Not Scanning")
					.foregroundStyle(bluetooth.isScanning ? .green : .gray)
				if let peripheral = bluetooth.connectedPeripheral {
					Text("Connected Peripheral: \(peripheral.name ?? "N/A")")
						.foregroundStyle(.green)
				} else {
					Text("No Connected Peripheral").foregroundStyle(.red)
				}
			}
			List {
				Section(header: Text("Discovered Peripherals")) {
					ForEach(bluetooth.peripherals, id: \.identifier) { peripheral in
						HStack {
							Text(peripheral.name ?? "N/A")
							Button(action: {
								if bluetooth.isConnected {
									bluetooth.disconnect(peripheral)
								} else {
									bluetooth.connect(peripheral)
								}
							}, label: {
								Text(bluetooth.isConnected ? "Disconnect" : "Connect")
							})
						}
					}
				}
				
				// Actions section
				if bluetooth.isConnected {
					Section(header: Text("Actions")) {
						Button("Send NoteOn Event") {
							bluetooth.sendNoteOn()
						}
						Button("Send NoteOff Event") {
							bluetooth.sendNoteOff()
						}
						Button("Send SysEx") {
							bluetooth.sendSysEx()
						}
					}
				}
			}
		}
		.padding()
	}
}
