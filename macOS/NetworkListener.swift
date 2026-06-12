import Foundation
import CoreBluetooth
import Combine

class NetworkListener: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    
    @Published var isListening = false
    @Published var publishedServiceName: String = ""
    @Published var currentIP: String = "Bluetooth Mode"
    
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    
    override init() {
        super.init()
    }
    
    func start() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Bluetooth Peripheral powered on. Setting up service...")
            setupService()
        case .poweredOff:
            print("Bluetooth Peripheral powered off.")
            stopAdvertising()
        case .unauthorized:
            print("Bluetooth Peripheral unauthorized. Check system settings.")
            DispatchQueue.main.async {
                self.isListening = false
            }
        case .unsupported:
            print("Bluetooth is unsupported on this device.")
            DispatchQueue.main.async {
                self.isListening = false
            }
        default:
            break
        }
    }
    
    private func setupService() {
        guard let peripheralManager = peripheralManager else { return }
        
        let mouseChar = CBMutableCharacteristic(
            type: Self.characteristicUUID,
            properties: [.writeWithoutResponse, .write],
            value: nil,
            permissions: [.writeable]
        )
        
        let mouseService = CBMutableService(type: Self.serviceUUID, primary: true)
        mouseService.characteristics = [mouseChar]
        
        peripheralManager.removeAllServices()
        peripheralManager.add(mouseService)
        
        self.characteristic = mouseChar
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Failed to add service: \(error.localizedDescription)")
            return
        }
        
        print("Service added successfully. Starting advertising...")
        startAdvertising()
    }
    
    private func startAdvertising() {
        guard let peripheralManager = peripheralManager, peripheralManager.state == .poweredOn else { return }
        
        let macName = Host.current().localizedName ?? "Mac Mouse Server"
        self.publishedServiceName = macName
        
        // CRITICAL: Do NOT include long name in advertisementData key
        // to avoid exceeding 28 byte limit which drops Service UUID.
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]
        ]
        
        peripheralManager.startAdvertising(advertisementData)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Failed to start advertising: \(error.localizedDescription)")
                self.isListening = false
            } else {
                print("Advertising started successfully for Service UUID: \(Self.serviceUUID)")
                self.isListening = true
            }
        }
    }
    
    private func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        DispatchQueue.main.async {
            self.isListening = false
            self.publishedServiceName = ""
        }
    }
    
    // Handle write requests from Central (Watch App)
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == Self.characteristicUUID {
                if let data = request.value {
                    processMessage(data)
                }
                
                // Respond back to central if request type requires response
                if request.characteristic.properties.contains(.write) {
                    peripheralManager?.respond(to: request, withResult: .success)
                }
            } else {
                peripheralManager?.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }
    
    private func processMessage(_ data: Data) {
        do {
            let command = try JSONDecoder().decode(MouseCommand.self, from: data)
            DispatchQueue.main.async {
                switch command.type {
                case .move:
                    if let dx = command.dx, let dy = command.dy {
                        MouseController.shared.moveMouse(dx: dx, dy: dy)
                    }
                case .action:
                    if let action = command.action {
                        MouseController.shared.performAction(action)
                    }
                }
            }
        } catch {
            print("Failed to decode command: \(error)")
        }
    }
}
