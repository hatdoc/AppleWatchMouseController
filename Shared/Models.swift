import Foundation

// Defines actions that can be triggered by gestures
public enum GestureAction: String, Codable, CaseIterable, Identifiable {
    case leftClick = "Left Click"
    case rightClick = "Right Click"
    case doubleClick = "Double Click"
    case spacebar = "Spacebar (Play/Pause Media)"
    case zoomIn = "Zoom In"
    case zoomOut = "Zoom Out"
    case none = "Do Nothing"
    
    public var id: String { self.rawValue }
}

// Defines the command payload sent from Watch to Mac over UDP
public struct MouseCommand: Codable {
    public enum CommandType: String, Codable {
        case move
        case action
    }

    public let type: CommandType
    
    // For movement
    public let dx: Double?
    public let dy: Double?
    
    // For clicks / actions
    public let action: GestureAction?
    
    public init(type: CommandType, dx: Double? = nil, dy: Double? = nil, action: GestureAction? = nil) {
        self.type = type
        self.dx = dx
        self.dy = dy
        self.action = action
    }
}
