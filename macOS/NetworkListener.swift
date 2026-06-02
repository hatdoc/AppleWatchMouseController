import Foundation
import Network
import Combine

class NetworkListener: ObservableObject {
    private var listener: NWListener?
    @Published var isListening = false
    @Published var currentIP: String = "Unknown"
    @Published var publishedServiceName: String = ""
    
    func start() {
        do {
            let port = NWEndpoint.Port(rawValue: 5050)!
            listener = try NWListener(using: .udp, on: port)
            
            // Advertise the server as a Bonjour service
            let serviceName = Host.current().localizedName ?? "Mac Mouse Server"
            listener?.service = NWListener.Service(name: serviceName, type: "_applewatchmouse._udp")
            
            listener?.serviceRegistrationUpdateHandler = { [weak self] serviceChange in
                DispatchQueue.main.async {
                    switch serviceChange {
                    case .add(let endpoint):
                        if case let .service(name, _, _, _) = endpoint {
                            self?.publishedServiceName = name
                            print("Bonjour service published: \(name)")
                        }
                    case .remove(_):
                        self?.publishedServiceName = ""
                        print("Bonjour service stopped")
                    @unknown default:
                        break
                    }
                }
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.currentIP = self?.getIPAddress() ?? "Unknown"
                        print("Listening on UDP port \(port)")
                    case .failed(let error):
                        print("Listener failed with error: \(error)")
                        self?.isListening = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInteractive))
        } catch {
            print("Failed to create listener: \(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInteractive))
        receive(on: connection)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            if let data = data {
                self?.processMessage(data)
            }
            if error == nil && !isComplete {
                self?.receive(on: connection)
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
    
    // Helper to get local IP address for display
    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name: String = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" { // Wi-Fi interfaces
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
