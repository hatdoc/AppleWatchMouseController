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
                    Text("Status: Listening")
                        .foregroundColor(.green)
                    Text("IP Address: \(networkListener.currentIP)")
                        .font(.body)
                        .textSelection(.enabled)
                    
                    if !networkListener.publishedServiceName.isEmpty {
                        Text("Bonjour: \(networkListener.publishedServiceName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text("Bonjour: Advertising...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Port: 5050")
                        .font(.caption)
                } else {
                    Text("Status: Disconnected")
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
