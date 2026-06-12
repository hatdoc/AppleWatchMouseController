import Foundation
import Network
import Combine

class NetworkClient: ObservableObject {
    static let shared = NetworkClient()

    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var retryTimer: Timer?

    @Published var isConnected: Bool = false
    @Published var connectedHostName: String = ""
    @Published var isSearching: Bool = false
    @Published var discoveredServers: [NWEndpoint] = []
    @Published var browserFailed: Bool = false

    private let port = NWEndpoint.Port(rawValue: 5050)!

    private init() {
        let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
        if isAutoConnectEnabled {
            startBrowsing()
        }
    }

    func startBrowsing() {
        // Stop any existing browser before starting fresh
        stopBrowsing()

        browserFailed = false
        discoveredServers.removeAll()
        isSearching = true

        // Force Wi-Fi interface so VPN (ipsec1) doesn't intercept Bonjour discovery
        let parameters = NWParameters.udp
        parameters.requiredInterfaceType = .wifi
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_applewatchmouse._udp", domain: nil)
        let newBrowser = NWBrowser(for: descriptor, using: parameters)
        self.browser = newBrowser

        newBrowser.browseResultsChangedHandler = { [weak self] results, changes in
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

        newBrowser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.browserFailed = false
                    print("Browser ready, scanning for Bonjour services...")
                case .failed(let error):
                    print("Browser failed: \(error)")
                    self.isSearching = false
                    self.browserFailed = true
                    // Auto-retry after 3 seconds (handles permission denial recovery)
                    self.scheduleRetry()
                case .cancelled:
                    self.isSearching = false
                case .waiting(let error):
                    // This fires when Local Network permission hasn't been granted yet
                    print("Browser waiting (likely needs Local Network permission): \(error)")
                default:
                    break
                }
            }
        }

        newBrowser.start(queue: .global(qos: .userInitiated))
    }

    func stopBrowsing() {
        retryTimer?.invalidate()
        retryTimer = nil
        browser?.browseResultsChangedHandler = nil
        browser?.stateUpdateHandler = nil
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func scheduleRetry() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            print("Retrying Bonjour browse...")
            self.startBrowsing()
        }
    }

    func connect(to ip: String) {
        let host = NWEndpoint.Host(ip)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        connect(to: endpoint)
    }

    func connect(to endpoint: NWEndpoint) {
        // Don't reconnect if already connected to same endpoint
        if isConnected { return }

        connection?.cancel()

        // Extract a friendly name for UI display
        if case let .service(name, _, _, _) = endpoint {
            self.connectedHostName = name
        } else if case let .hostPort(host, _) = endpoint {
            self.connectedHostName = "\(host)"
        } else {
            self.connectedHostName = "Mac Server"
        }

        print("Connecting to \(endpoint)...")

        // Force Wi-Fi interface to bypass any active VPN (e.g. ipsec1) that blocks
        // local Bonjour/mDNS traffic via NECP policy denial.
        let params = NWParameters.udp
        params.requiredInterfaceType = .wifi
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false

        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.browserFailed = false
                    print("Connected to \(endpoint)")
                case .failed(let error):
                    self.isConnected = false
                    self.connectedHostName = ""
                    print("Connection failed: \(error)")
                    // Auto-retry browsing after a connection failure
                    let isAutoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnect") as? Bool ?? true
                    if isAutoConnectEnabled {
                        self.scheduleRetry()
                    }
                case .cancelled:
                    self.isConnected = false
                    self.connectedHostName = ""
                default:
                    break
                }
            }
        }

        conn.start(queue: .global(qos: .userInteractive))
    }

    func disconnect() {
        stopBrowsing()
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
