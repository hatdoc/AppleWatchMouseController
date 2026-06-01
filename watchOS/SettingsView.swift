import SwiftUI

struct SettingsView: View {
    @AppStorage("hostIP") private var hostIP: String = "192.168.1.X"
    @AppStorage("sensitivity") private var sensitivity: Double = 1.0
    
    @AppStorage("singleTapAction") private var singleTapAction: GestureAction = .leftClick
    @AppStorage("doubleTapAction") private var doubleTapAction: GestureAction = .doubleClick
    @AppStorage("useBluetooth") private var useBluetooth: Bool = false
    
    @State private var showBluetoothWarning = false
    
    var body: some View {
        Form {
            Section(header: Text("Connection")) {
                TextField("Mac IP Address", text: $hostIP)
                    .textContentType(.URL)
                
                Toggle("Use Bluetooth (Beta)", isOn: Binding(
                    get: { useBluetooth },
                    set: { newValue in
                        if newValue {
                            showBluetoothWarning = true
                        }
                        useBluetooth = newValue
                    }
                ))
            }
            
            Section(header: Text("Sensitivity")) {
                Slider(value: $sensitivity, in: 0.1...5.0, step: 0.1)
                Text("Current: \(String(format: "%.1f", sensitivity))x")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Gestures")) {
                Picker("Single Tap", selection: $singleTapAction) {
                    ForEach(GestureAction.allCases) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
                
                Picker("Double Tap", selection: $doubleTapAction) {
                    ForEach(GestureAction.allCases) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .alert(isPresented: $showBluetoothWarning) {
            Alert(
                title: Text("Bluetooth Mode"),
                message: Text("Bluetooth requires manual pairing and currently has slightly higher latency. Local Network (UDP) is highly recommended for best performance. Continuing will fallback to UDP for now."),
                dismissButton: .default(Text("OK")) {
                    useBluetooth = false // Fallback logic as stub
                }
            )
        }
    }
}
