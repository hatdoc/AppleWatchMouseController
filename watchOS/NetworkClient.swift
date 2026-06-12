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
    @Published var bluetoothPermissionDenied: Bool = false
    
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startBrowsing() {
        discoveredServers.removeAll()
        bluetoothPermissionDenied = false
        
        guard let centralManager = centralManager else { return }
        
        if centralManager.state == .poweredOn {
            isSearching = true
            // Scan only for the specified service UUID.
            centralManager.scanForPeripherals(withServices: [Self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            print("Scanning for BLE peripherals with service UUID: \(Self.serviceUUID)...")
        } else {
            print("Central manager state is not poweredOn: \(centralManager.state.rawValue)")
            isSearching = false
        }
    }
    
    func stopBrowsing() {
        centralManager?.stopScan()
        isSearching = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopBrowsing()
        
        if isConnected {
            disconnect()
        }
        
        connectedPeripheral = peripheral
        connectedHostName = peripheral.name ?? "Mac Server"
        
        print("Connecting to \(connectedHostName)...")
        centralManager?.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        stopBrowsing()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writeCharacteristic = nil
        isConnected = false
        connectedHostName = ""
    }
    
    func send(command: MouseCommand) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic,
              isConnected else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(command)
            // Use withoutResponse for movement to minimize latency,
            // and write with response for actions.
            let writeType: CBCharacteristicWriteType = (command.type == .move) ? .withoutResponse : .withResponse
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
                self.bluetoothPermissionDenied = false
                let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
                if isAutoConnectEnabled {
                    self.startBrowsing()
                }
            case .poweredOff:
                print("Central manager powered off.")
                self.disconnect()
            case .unauthorized:
                print("Bluetooth unauthorized.")
                self.bluetoothPermissionDenied = true
                self.disconnect()
            default:
                break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.discoveredServers.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredServers.append(peripheral)
                print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
                
                // Auto-connect if enabled
                let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
                if isAutoConnectEnabled && !self.isConnected {
                    self.connect(to: peripheral)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "no details")")
        DispatchQueue.main.async { [weak self] in
            self?.disconnect()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        DispatchQueue.main.async { [weak self] in
            self?.disconnect()
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        
        guard let services = peripheral.services else {
            print("No services discovered.")
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        
        for service in services {
            if service.uuid == Self.serviceUUID {
                print("Discovered service: \(service.uuid). Discovering characteristics...")
                peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
                return
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("No characteristics discovered.")
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == Self.characteristicUUID {
                print("Found write characteristic: \(characteristic.uuid)")
                self.writeCharacteristic = characteristic
                
                DispatchQueue.main.async { [weak self] in
                    self?.isConnected = true
                    // Peripheral name is sometimes nil initially; retrieve name from peripheral.name
                    self?.connectedHostName = peripheral.name ?? "Mac Server"
                }
                return
            }
        }
    }
}
