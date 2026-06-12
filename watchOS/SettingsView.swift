import SwiftUI

struct SettingsView: View {
    @AppStorage("sensitivity") private var sensitivity: Double = 1.0
    @AppStorage("autoConnect") private var autoConnect: Bool = true
    
    @AppStorage("singleTapAction") private var singleTapAction: GestureAction = .leftClick
    @AppStorage("doubleTapAction") private var doubleTapAction: GestureAction = .doubleClick
    
    var body: some View {
        Form {
            Section(header: Text("Connection")) {
                Toggle("Auto-Connect", isOn: Binding(
                    get: { autoConnect },
                    set: { newValue in
                        autoConnect = newValue
                        if newValue {
                            NetworkClient.shared.startBrowsing()
                        } else {
                            NetworkClient.shared.stopBrowsing()
                            NetworkClient.shared.disconnect()
                        }
                    }
                ))
                
                HStack {
                    Text("Connection Mode")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Bluetooth")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .bold()
                }
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
    }
}
