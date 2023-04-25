import Foundation
@_implementationOnly import CBCWally

public enum Wally {
    private static var _initialized: Bool = {
        wally_init(0)
        return true
    }()
    
    public static func initialize() {
        _ = _initialized
    }
}
