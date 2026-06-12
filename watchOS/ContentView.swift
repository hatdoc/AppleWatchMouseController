import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var networkClient = NetworkClient.shared
    
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
                    searchingView
                } else {
                    trackpadView
                }
            }
            .navigationTitle("Mouse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .onAppear {
            networkClient.startBrowsing()
        }
    }
    
    // MARK: - Subviews
    
    private var searchingView: some View {
        VStack(spacing: 6) {
            Spacer()
            
            // Pulsing BLE / Status Icon
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
                
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 44, height: 44)
                
                Image(systemName: networkClient.bluetoothPermissionDenied ? "exclamationmark.triangle.fill" : "wave.3.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(networkClient.bluetoothPermissionDenied ? .orange : .blue)
            }
            .onAppear {
                withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
            .onDisappear {
                isPulsing = false
            }
            
            VStack(spacing: 2) {
                Text(networkClient.bluetoothPermissionDenied ? "Bluetooth Denied" : "Searching...")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text(networkClient.bluetoothPermissionDenied ? "Enable Bluetooth in Settings" : "Start Mac Mouse Server")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            
            Spacer()
            
            if !networkClient.discoveredServers.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(networkClient.discoveredServers, id: \.identifier) { peripheral in
                            Button(action: {
                                networkClient.connect(to: peripheral)
                            }) {
                                HStack {
                                    Image(systemName: "macmini")
                                        .foregroundColor(.green)
                                        .font(.caption2)
                                    Text(peripheral.name ?? "Mac Server")
                                        .font(.system(.caption2, design: .rounded))
                                        .bold()
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 55)
            } else {
                if !networkClient.bluetoothPermissionDenied && !networkClient.isSearching {
                    Button("Scan") {
                        networkClient.startBrowsing()
                    }
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.blue)
                } else if networkClient.isSearching {
                    Text("Scanning BLE...")
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var trackpadView: some View {
        VStack(spacing: 3) {
            // Connection Status Header
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                    .shadow(color: .green, radius: 2)
                Text(networkClient.connectedHostName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    networkClient.disconnect()
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)
            
            // Interactive Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
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
                            colors: [.blue.opacity(0.5), .blue.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 12
                        ))
                        .frame(width: 24, height: 24)
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
        }
        .padding(.bottom, 2)
        .padding(.horizontal, 2)
    }
}
