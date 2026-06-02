import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var networkClient = NetworkClient.shared
    
    @AppStorage("hostIP") private var hostIP: String = "192.168.1.X"
    @AppStorage("sensitivity") private var sensitivity: Double = 1.0
    @AppStorage("autoConnect") private var autoConnect: Bool = true
    
    @AppStorage("singleTapAction") private var singleTapAction: GestureAction = .leftClick
    @AppStorage("doubleTapAction") private var doubleTapAction: GestureAction = .doubleClick
    
    @State private var lastDragLocation: CGPoint? = nil
    @State private var dragLocation: CGPoint? = nil
    @State private var isPulsing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if !networkClient.isConnected {
                    VStack(spacing: 8) {
                        if autoConnect {
                            searchingView
                        } else {
                            manualConnectView
                        }
                    }
                } else {
                    trackpadView
                }
            }
            .navigationTitle("Mouse Controller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .onAppear {
            if autoConnect {
                networkClient.startBrowsing()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchingView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
                
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "desktopcomputer")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .onAppear {
                withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
            .onDisappear {
                isPulsing = false
            }
            
            Text("Searching for Mac...")
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !networkClient.discoveredServers.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(networkClient.discoveredServers, id: \.self) { endpoint in
                            Button(action: {
                                networkClient.connect(to: endpoint)
                            }) {
                                HStack {
                                    Image(systemName: "macmini")
                                        .foregroundColor(.green)
                                        .font(.footnote)
                                    Text(friendlyName(for: endpoint))
                                        .font(.system(.caption2, design: .rounded))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 65)
            } else {
                Button("Connect to Saved IP") {
                    networkClient.connect(to: hostIP)
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.blue)
            }
        }
    }
    
    private var manualConnectView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Not Connected")
                .foregroundColor(.red)
                .font(.footnote)
            
            Button("Connect to \(hostIP)") {
                networkClient.connect(to: hostIP)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .font(.footnote)
            
            Button("Enable Auto-Connect") {
                autoConnect = true
                networkClient.startBrowsing()
            }
            .font(.system(.caption2, design: .rounded))
            .foregroundColor(.secondary)
        }
    }
    
    private var trackpadView: some View {
        VStack(spacing: 4) {
            // Connection Status Header
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: .green, radius: 2)
                Text(networkClient.connectedHostName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    networkClient.disconnect()
                }) {
                    Image(systemName: "power")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 4)
            
            // Interactive Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.01))
                    )
                
                // Trackpad Text Layer
                VStack {
                    Spacer()
                    Text("TRACKPAD")
                        .font(.system(size: 8, weight: .ultraLight))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.12))
                    Spacer()
                }
                
                // Interactive Touch Dot
                if let dragLoc = dragLocation {
                    Circle()
                        .fill(RadialGradient(
                            colors: [.blue.opacity(0.6), .blue.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 15
                        ))
                        .frame(width: 30, height: 30)
                        .position(dragLoc)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragLocation = value.location
                        if let last = lastDragLocation {
                            let dx = (value.location.x - last.x) * sensitivity
                            let dy = (value.location.y - last.y) * sensitivity
                            
                            if dx != 0 || dy != 0 {
                                let command = MouseCommand(type: .move, dx: dx, dy: dy, action: nil)
                                networkClient.send(command: command)
                            }
                        }
                        lastDragLocation = value.location
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragLocation = nil
                        }
                        lastDragLocation = nil
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    networkClient.send(command: MouseCommand(type: .action, action: doubleTapAction))
                }
                .exclusively(
                    before: TapGesture(count: 1).onEnded {
                        networkClient.send(command: MouseCommand(type: .action, action: singleTapAction))
                    }
                )
            )
            .padding(.bottom, 2)
        }
    }
    
    // MARK: - Helpers
    
    private func friendlyName(for endpoint: NWEndpoint) -> String {
        if case let .service(name, _, _, _) = endpoint {
            return name
        } else if case let .hostPort(host, _) = endpoint {
            return "\(host)"
        }
        return "Mac Server"
    }
}
