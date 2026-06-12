import Foundation
import CoreBluetooth
import Combine

class NetworkClient: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = NetworkClient()
    
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    
    @Published var isConnected: Bool = false
    @Published var connectedHostName: String = ""
    @Published var isSearching: Bool = false
    @Published var discoveredServers: [CBPeripheral] = []
    
    // Service and Characteristic UUIDs for Bluetooth Communication
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    
    private override init() {
        super.init()
        // CoreBluetooth Central Manager initialization
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startBrowsing() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else { return }
        guard !isSearching else { return }
        
        discoveredServers.removeAll()
        isSearching = true
        
        // Scan for all peripherals to bypass watchOS hardware-level packet size filtering limitations.
        // Software filtering will check for our custom service UUID or name prefix.
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopBrowsing() {
        centralManager?.stopScan()
        isSearching = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopBrowsing()
        
        connectedPeripheral?.delegate = nil
        if let oldPeripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(oldPeripheral)
        }
        
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        
        connectedHostName = peripheral.name ?? "Mac Server"
        centralManager?.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writeCharacteristic = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
            self.connectedHostName = ""
            
            // Restart scanning if auto-connect is still enabled
            let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
            if isAutoConnectEnabled {
                self.startBrowsing()
            }
        }
    }
    
    func send(command: MouseCommand) {
        guard isConnected, let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else { return }
        
        do {
            let data = try JSONEncoder().encode(command)
            
            // Use writeWithoutResponse for higher frequency events (movements) to decrease latency
            let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            
            peripheral.writeValue(data, for: characteristic, type: writeType)
        } catch {
            print("Error encoding command: \(error)")
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch central.state {
            case .poweredOn:
                print("Central powered on.")
                let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
                if isAutoConnectEnabled {
                    self.startBrowsing()
                }
            case .poweredOff:
                print("Central powered off.")
                self.disconnect()
            case .unauthorized:
                print("Central unauthorized. Please grant Bluetooth permissions.")
                self.disconnect()
            case .unsupported:
                print("Bluetooth is unsupported on this Apple Watch.")
                self.disconnect()
            default:
                break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Software filtering check
            var isMouseServer = false
            if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                isMouseServer = serviceUUIDs.contains(Self.serviceUUID)
            }
            
            // Name prefix fallback filter
            if !isMouseServer, let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                isMouseServer = localName.hasPrefix("MouseServer:")
            } else if !isMouseServer, let peripheralName = peripheral.name {
                isMouseServer = peripheralName.hasPrefix("MouseServer:")
            }
            
            if isMouseServer {
                if !self.discoveredServers.contains(where: { $0.identifier == peripheral.identifier }) {
                    self.discoveredServers.append(peripheral)
                    
                    let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
                    if isAutoConnectEnabled && !self.isConnected {
                        self.connect(to: peripheral)
                    }
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([Self.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(error?.localizedDescription ?? "no error description")")
        disconnect()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        disconnect()
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            disconnect()
            return
        }
        
        guard let services = peripheral.services else {
            print("No services found.")
            disconnect()
            return
        }
        
        for service in services {
            if service.uuid == Self.serviceUUID {
                print("Found service: \(service.uuid). Discovering characteristics...")
                peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
                return
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            disconnect()
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("No characteristics found.")
            disconnect()
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == Self.characteristicUUID {
                print("Found write characteristic: \(characteristic.uuid)")
                self.writeCharacteristic = characteristic
                
                DispatchQueue.main.async { [weak self] in
                    self?.isConnected = true
                }
                return
            }
        }
    }
}
