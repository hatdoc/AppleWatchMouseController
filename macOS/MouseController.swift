import Foundation
import CoreGraphics
import ApplicationServices

class MouseController {
    static let shared = MouseController()
    
    private init() {}
    
    // Check and request accessibility permissions
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessEnabled
    }
    
    func moveMouse(dx: Double, dy: Double) {
        guard let currentPos = CGEvent(source: nil)?.location else { return }
        
        let newX = currentPos.x + CGFloat(dx)
        let newY = currentPos.y + CGFloat(dy)
        
        let newPoint = CGPoint(x: newX, y: newY)
        
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newPoint, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }
    
    func performAction(_ action: GestureAction) {
        guard let currentPos = CGEvent(source: nil)?.location else { return }
        
        switch action {
        case .leftClick:
            let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentPos, mouseButton: .left)
            let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: currentPos, mouseButton: .left)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            
        case .rightClick:
            let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: currentPos, mouseButton: .right)
            let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: currentPos, mouseButton: .right)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            
        case .doubleClick:
            let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentPos, mouseButton: .left)
            let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: currentPos, mouseButton: .left)
            
            down?.setIntegerValueField(.mouseEventClickState, value: 2)
            up?.setIntegerValueField(.mouseEventClickState, value: 2)
            
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            
        case .spacebar:
            let spaceKeyCode: CGKeyCode = 49
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: spaceKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: spaceKeyCode, keyDown: false)
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
        case .zoomIn:
            // Simulate cmd +
            let plusKeyCode: CGKeyCode = 24
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: plusKeyCode, keyDown: true)
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: plusKeyCode, keyDown: false)
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
        case .zoomOut:
            // Simulate cmd -
            let minusKeyCode: CGKeyCode = 27
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: minusKeyCode, keyDown: true)
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: minusKeyCode, keyDown: false)
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
        case .none:
            break
        }
    }
}
