import Foundation
import Network
import Combine

class NetworkClient: ObservableObject {
    static let shared = NetworkClient()
    
    private var connection: NWConnection?
    @Published var isConnected: Bool = false
    @Published var hostIP: String = ""
    
    private let port = NWEndpoint.Port(rawValue: 5050)!
    
    func connect(to ip: String) {
        self.hostIP = ip
        
        // Ensure IP is somewhat valid to prevent instant crashes
        let host = NWEndpoint.Host(ip)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        connection?.cancel()
        
        connection = NWConnection(to: endpoint, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    print("Connected to \(ip)")
                case .failed(let error):
                    self?.isConnected = false
                    print("Connection failed: \(error)")
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: .global(qos: .userInteractive))
    }
    
    func send(command: MouseCommand) {
        guard let connection = connection, connection.state == .ready else { return }
        
        do {
            let data = try JSONEncoder().encode(command)
            connection.send(content: data, completion: .idempotent)
        } catch {
            print("Error encoding command: \(error)")
        }
    }
}
