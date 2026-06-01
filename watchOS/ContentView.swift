import SwiftUI

struct ContentView: View {
    @StateObject private var networkClient = NetworkClient.shared
    
    @AppStorage("hostIP") private var hostIP: String = "192.168.1.X"
    @AppStorage("sensitivity") private var sensitivity: Double = 1.0
    
    @AppStorage("singleTapAction") private var singleTapAction: GestureAction = .leftClick
    @AppStorage("doubleTapAction") private var doubleTapAction: GestureAction = .doubleClick
    
    @State private var lastDragLocation: CGPoint? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if !networkClient.isConnected {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Not Connected")
                            .foregroundColor(.red)
                            .font(.footnote)
                        
                        Button("Connect") {
                            networkClient.connect(to: hostIP)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                } else {
                    Text("Canvas Area")
                        .foregroundColor(.white.opacity(0.2))
                        .font(.caption)
                }
            }
            .contentShape(Rectangle()) // Ensure the whole ZStack catches gestures
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
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
            .navigationTitle("Controller")
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
            if !hostIP.isEmpty && hostIP != "192.168.1.X" {
                networkClient.connect(to: hostIP)
            }
        }
    }
}
