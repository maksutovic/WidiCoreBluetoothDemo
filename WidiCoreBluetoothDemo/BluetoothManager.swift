import Foundation
import CoreBluetooth
import MIDIKit

final class BluetoothManager: NSObject, ObservableObject {
	static let shared = BluetoothManager()
	static let bleMidiServiceUUID: CBUUID = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
	
	static let bleMidiCharacteristicUUID: CBUUID = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")
	
	let midiParser = MIDI1Parser()
	
	private var centralManager: CBCentralManager!
	@Published var connectedPeripheral: CBPeripheral? {
		didSet {
			DispatchQueue.main.async {
				if self.connectedPeripheral == nil {
					self.isConnected = false
				} else {
					self.isConnected = true
				}
			}
		}
	}
	
	private var connectedPeripheralBLECharacteristic: CBCharacteristic?
	
	@Published var isScanning: Bool = false
	@Published var isConnected: Bool = false
	private var discoveredPeripherals: Set<CBPeripheral> = Set() {
		didSet {
			DispatchQueue.main.async {
				self.peripherals = Array(self.discoveredPeripherals)
			}
		}
	}
	@Published var peripherals: [CBPeripheral] = []
	
	
	private override init() {
		super.init()
		centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .default))
	}

}

extension BluetoothManager: CBCentralManagerDelegate {
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		switch central.state {
			case .unknown:
				fatalError()
			case .resetting:
				print("CBCentral resetting")
			case .unsupported:
				print("CBCentral Unsupported")
			case .unauthorized:
				print("CBCentral Unauthorized")
			case .poweredOff:
				print("CBCentral powered off")
			case .poweredOn:
                if let saved = UserDefaults.standard.object(forKey: "SavedTilt") as? String {
                    if let uuid = UUID(uuidString: saved) {
                        let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                        print("KNOWN PERIPHERALS: \(knownPeripherals.debugDescription)")
                        if let peripheral = knownPeripherals.first {
                            //We have a stored peripheral lets connect
                            DispatchQueue.main.async {
                                self.connectedPeripheral = peripheral
                            }
                            switch peripheral.state {
                                case .disconnected:
                                    centralManager.connect(self.connectedPeripheral!)
                                case .connecting:
                                    print("Peripheral is connecting")
                                case .connected:
                                    print("Peripheral is connected")
                                    centralManager.connect(self.connectedPeripheral!)
                                case .disconnecting:
                                    print("Peripheral is disconnecting")
                                @unknown default:
                                    fatalError()
                            }
                        }
                    }
                } else {
                    centralManager.scanForPeripherals(withServices: [BluetoothManager.bleMidiServiceUUID])
                    DispatchQueue.main.async {
                        self.isScanning = true
                    }
                }

			@unknown default:
				fatalError()
		}
	}
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		discoveredPeripherals.insert(peripheral)
	}
	
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		DispatchQueue.main.async {
			self.connectedPeripheral = peripheral
			self.connectedPeripheral?.delegate = self
			self.centralManager.stopScan()
			self.isScanning = false
            let uuidString = peripheral.identifier.uuidString
            UserDefaults.standard.set(uuidString, forKey: "SavedTilt")
			self.connectedPeripheral?.discoverServices([BluetoothManager.bleMidiServiceUUID])
		}
	}
	
	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		DispatchQueue.main.async {
			self.connectedPeripheral = nil
			self.discoveredPeripherals.removeAll()
			self.centralManager.scanForPeripherals(withServices: nil)
			self.isScanning = true
		}
	}
	
	func connect(_ peripheral: CBPeripheral) {
		centralManager.connect(peripheral)
	}
	
	func disconnect(_ peripheral: CBPeripheral) {
		centralManager.cancelPeripheralConnection(peripheral)
	}
	
}

extension BluetoothManager: CBPeripheralDelegate {
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		if let error {
			print(error.localizedDescription)
		}
		guard let services = self.connectedPeripheral?.services else {
			print("Cannot unwrap services")
			return
		}
		for service in services {
			print("\(peripheral.name ?? "N/A"): Service: \(service.description)")
			self.connectedPeripheral?.discoverCharacteristics(nil, for: service)
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		if let error {
			print(error.localizedDescription)
		}
		guard let chars = service.characteristics else {
			print("Cannot unwrap characteristics")
			return
		}
		for char in chars {
			print("\(peripheral.name ?? "N/A"): Char: \(char.description)")
            if let value = char.value {
                print("READ CHAR VALUE:\(Array(value).hexString)")
            } else {
                print("CAN'T READ VALUE")
            }
			self.connectedPeripheral?.discoverDescriptors(for: char)
            if char.properties.contains(.read) {
                print("READ")
            }
            if char.properties.contains(.writeWithoutResponse) {
                print("WRITE WITHOUT RESPONE")
            }
            if char.properties.contains(.write) {
                print("WRITE")
            }
            if char.properties.contains(.notify) {
                print("NOTIFY")
            }
            if char.properties.contains(.indicate) {
                print("INDICATE")
            }
            if char.properties.contains(.authenticatedSignedWrites) {
                print("AUTHENTICATED SIGNED WRITES")
            }
            if char.properties.contains(.extendedProperties) {
                print("EXTENDED PROPERTIES")
            }
            if char.properties.contains(.notifyEncryptionRequired) {
                print("NOTIFY ENCRYPTION REQUIRED")
            }
            if char.properties.contains(.indicateEncryptionRequired) {
                print("INDICATE ENCRYPTION REQUIRED")
            }
			if char.uuid == BluetoothManager.bleMidiCharacteristicUUID {
                connectedPeripheral?.readValue(for: char)
				connectedPeripheral?.setNotifyValue(true, for: char)
				connectedPeripheralBLECharacteristic = char
			}
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
		if let error {
			print(error.localizedDescription)
		}
		guard let descriptors = characteristic.descriptors else {
			print("Cannot unwrap descriptors")
			return
		}
		for descriptor in descriptors {
            print("\(peripheral.name ?? "N/A") Descriptor:\(descriptor)")
			self.connectedPeripheral?.readValue(for: descriptor)
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
		if let error {
			print(error.localizedDescription)
		}
        print("DID UPDATE VALUE FOR DESC")
		print("\(peripheral.name ?? "N/A"): Descriptor: \(descriptor.description) Value: \(String(describing: descriptor.value))")
	}
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error {
			print(error.localizedDescription)
		}
		guard let value = characteristic.value else {
			print("cannot unwrap characteristic value")
			return
		}
		let events = midiParser.parsedEvents(in: Array(value))
		for event in events {
			print("*** Recived Data from: \(peripheral.name ?? "N/A"): Charasteristic: \(characteristic.uuid)\nMIDI-Event: \(event.description)***")
		}

	}
}

extension BluetoothManager {
	public func sendNoteOn() {
		let event = MIDIEvent.noteOn(67, velocity: .midi1(100), channel: 0)
		let packet = createBLEMIDIPacket(midiMessage: event.midi1RawBytes())
		if let char = connectedPeripheralBLECharacteristic {
			print("--- Sending:\(event) to: \(connectedPeripheral?.name ?? "N/A") ---")
			connectedPeripheral?.writeValue(Data(packet), for: char, type: .withoutResponse)
			print("--- \(connectedPeripheral?.name ?? "N/A") wrote: \(packet.hexString) to: \(char.uuid) ---")
		}
	}
	public func sendNoteOff() {
		let event = MIDIEvent.noteOff(67, velocity: .midi1(100), channel: 0)
		let packet = createBLEMIDIPacket(midiMessage: event.midi1RawBytes())
		if let char = connectedPeripheralBLECharacteristic {
			print("--- Sending:\(event) to: \(connectedPeripheral?.name ?? "N/A") ---")
			connectedPeripheral?.writeValue(Data(packet), for: char, type: .withoutResponse)
			print("--- \(connectedPeripheral?.name ?? "N/A") wrote: \(packet.hexString) to: \(char.uuid) ---")
		}
	}
	
	public func sendSysEx() {
		if let event = try? MIDIEvent.sysEx7(manufacturer: .threeByte(byte2: 0x02, byte3: 0x55), data: [0x01, 0x26, 0x00, 0x08, 0x30, 0x1B]) {
			let packet = createBLEMIDIPacketForSysEx(midiSysExMessage: event.midi1RawBytes())
			if let char = connectedPeripheralBLECharacteristic {
				print("--- Sending:\(event) to: \(connectedPeripheral?.name ?? "N/A") ---")
				connectedPeripheral?.writeValue(Data(packet), for: char, type: .withoutResponse)
				print("--- \(connectedPeripheral?.name ?? "N/A") wrote: \(packet.hexString) to: \(char.uuid) ---")
			}
		}
	}
	
	private func createBLEMIDIPacket(midiMessage: [UInt8]) -> [UInt8] {
		var packet: [UInt8] = []

		// Get current timestamp in milliseconds
		let timestamp = currentTimestampInMilliseconds()

		// Header byte
		let header: UInt8 = 0x80 | UInt8((timestamp >> 7) & 0x3F)
		packet.append(header)

		// Timestamp byte
		let timestampByte: UInt8 = 0x80 | UInt8(timestamp & 0x7F)
		packet.append(timestampByte)

		// MIDI message
		packet.append(contentsOf: midiMessage)

		return packet
	}
	
	private func createBLEMIDIPacketForSysEx(midiSysExMessage: [UInt8]) -> [UInt8] {
		var packet = [UInt8]()

		// Calculate the timestamp in milliseconds
		let timestamp = currentTimestampInMilliseconds() // 13-bit value

		// Header byte - setting bit 7 to 1, and bits 6-0 are the most significant bits of the timestamp
		let headerByte: UInt8 = 0x80 | UInt8((timestamp >> 7) & 0x3F) // 6 most significant bits
		packet.append(headerByte)

		// Timestamp byte - setting bit 7 to 1, and bits 6-0 are the least significant bits of the timestamp
		let timestampByte: UInt8 = 0x80 | UInt8(timestamp & 0x7F) // 7 least significant bits
		packet.append(timestampByte)
		
		// Adding the SysEx message excluding the SysEx end byte
		packet.append(contentsOf: midiSysExMessage.dropLast())

		// Adding the timestamp byte before SysEx end byte (EOX)
		packet.append(timestampByte)
		
		// Adding the SysEx end byte
		packet.append(0xF7)

		return packet
	}

	private func currentTimestampInMilliseconds() -> UInt16 {
		let nanoseconds = DispatchTime.now().uptimeNanoseconds
		let milliseconds = nanoseconds / 1_000_000 // Convert to milliseconds
		return UInt16(milliseconds & 0x1FFF) // Use only the last 13 bits
	}
}

extension Array where Element == UInt8 {
	var hexString: String {
		var mutableString = ""
		for byte in self {
			let byteString = String(format: "%02X", byte)
			mutableString.append("\(byteString) ")
		}
		return mutableString
	}
}
