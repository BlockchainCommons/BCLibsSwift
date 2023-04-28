import Foundation
@_implementationOnly import CBCWally

public struct WallyMapItem {
    let wrapped: UnsafeMutablePointer<wally_map_item>
    
    init(_ wrapped: UnsafeMutablePointer<wally_map_item>) {
        self.wrapped = wrapped
    }
    
    public var key: Data {
        Data(bytes: wrapped.pointee.key, count: wrapped.pointee.key_len)
    }
    
    public var value: Data {
        Data(bytes: wrapped.pointee.value, count: wrapped.pointee.value_len)
    }
}

public struct WallyMap {
    let wrapped: UnsafeMutablePointer<wally_map>
    
    init(_ wrapped: UnsafeMutablePointer<wally_map>) {
        self.wrapped = wrapped
    }
    
    public var count: Int {
        wrapped.pointee.num_items
    }
    
    public subscript(index: Int) -> WallyMapItem {
        precondition((0..<count).contains(index))
        return WallyMapItem(&wrapped.pointee.items[index])
    }
}
