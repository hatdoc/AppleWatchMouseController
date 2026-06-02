import Foundation
import Network
import Combine

class NetworkClient: ObservableObject {
    static let shared = NetworkClient()
    
    private var connection: NWConnection?
    private var browser: NWBrowser?
    
    @Published var isConnected: Bool = false
    @Published var hostIP: String = ""
    @Published var connectedHostName: String = ""
    @Published var isSearching: Bool = false
    @Published var discoveredServers: [NWEndpoint] = []
    
    private let port = NWEndpoint.Port(rawValue: 5050)!
    
    private init() {
        let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
        if isAutoConnectEnabled {
            startBrowsing()
        }
    }
    
    func startBrowsing() {
        guard browser == nil else { return }
        
        discoveredServers.removeAll()
        isSearching = true
        
        let parameters = NWParameters.udp
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_applewatchmouse._udp", domain: nil)
        browser = NWBrowser(for: descriptor, using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.discoveredServers = results.map { $0.endpoint }
                
                let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
                if isAutoConnectEnabled && !self.isConnected {
                    if let firstEndpoint = self.discoveredServers.first {
                        self.connect(to: firstEndpoint)
                    }
                }
            }
        }
        
        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .failed(let error):
                    print("Browser failed: \(error)")
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }
        
        browser?.start(queue: .global(qos: .userInitiated))
    }
    
    func stopBrowsing() {
        browser?.browseResultsChangedHandler = nil
        browser?.stateUpdateHandler = nil
        browser?.cancel()
        browser = nil
        isSearching = false
    }
    
    func connect(to ip: String) {
        self.hostIP = ip
        let host = NWEndpoint.Host(ip)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        connect(to: endpoint)
    }
    
    func connect(to endpoint: NWEndpoint) {
        connection?.cancel()
        
        // Extract a friendly name for UI display
        if case let .service(name, _, _, _) = endpoint {
            self.connectedHostName = name
        } else if case let .hostPort(host, _) = endpoint {
            self.connectedHostName = "\(host)"
        } else {
            self.connectedHostName = "Server"
        }
        
        connection = NWConnection(to: endpoint, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    print("Connected to \(endpoint)")
                case .failed(let error):
                    self?.isConnected = false
                    self?.connectedHostName = ""
                    print("Connection failed: \(error)")
                case .cancelled:
                    self?.isConnected = false
                    self?.connectedHostName = ""
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: .global(qos: .userInteractive))
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        connectedHostName = ""
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
