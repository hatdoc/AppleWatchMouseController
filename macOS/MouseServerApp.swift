import SwiftUI

@main
struct MouseServerApp: App {
    @StateObject private var networkListener = NetworkListener()
    
    var body: some Scene {
        MenuBarExtra("Mouse Server", systemImage: "computermouse") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Remote Mouse Server")
                    .font(.headline)
                
                Divider()
                
                if networkListener.isListening {
                    Text("Status: Advertising")
                        .foregroundColor(.green)
                    
                    if !networkListener.publishedServiceName.isEmpty {
                        Text("Name: \(networkListener.publishedServiceName)")
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    
                    Text("Service: E20A39F4-73F5...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Status: Bluetooth Offline")
                        .foregroundColor(.red)
                }
                
                Divider()
                
                Button("Check Accessibility Permissions") {
                    let granted = MouseController.shared.checkAccessibilityPermissions()
                    if granted {
                        print("Permissions granted.")
                    } else {
                        print("Permissions not granted. Check System Settings.")
                    }
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            // Make the window a bit wider for the IP address
            .frame(width: 250)
            .onAppear {
                // Prompt for accessibility immediately on first run
                _ = MouseController.shared.checkAccessibilityPermissions()
                networkListener.start()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
