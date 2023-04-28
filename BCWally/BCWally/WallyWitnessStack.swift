import Foundation
@_implementationOnly import CBCWally

public final class WallyWitnessItem {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx_witness_item>
    
    init(_ wrapped: UnsafeMutablePointer<wally_tx_witness_item>) {
        self.wrapped = wrapped
    }
    
    public var witness: Data? {
        let witnessLen = wrapped.pointee.witness_len
        guard
            witnessLen > 0,
            let witness = wrapped.pointee.witness
        else {
            return nil
        }
        return Data(bytes: witness, count: witnessLen)
    }
}

public final class WallyWitnessStack {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx_witness_stack>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_tx_witness_stack>) {
        self.wrapped = wrapped
    }
    
    public convenience init(_ witnesses: [Data]) {
        var newStack: UnsafeMutablePointer<wally_tx_witness_stack>!
        precondition(wally_tx_witness_stack_init_alloc(witnesses.count, &newStack) == WALLY_OK)
        for witness in witnesses {
            witness.withUnsafeByteBuffer { buf in
                precondition(wally_tx_witness_stack_add(newStack, buf.baseAddress, buf.count) == WALLY_OK)
            }
        }
        self.init(newStack)
    }
    
    public var count: Int {
        wrapped.pointee.num_items
    }
    
    public subscript(index: Int) -> WallyWitnessItem {
        precondition((0..<wrapped.pointee.num_items).contains(index))
        return WallyWitnessItem(&wrapped.pointee.items[index])
    }
    
    public func dispose() {
        wally_tx_witness_stack_free(wrapped)
        wrapped = nil
    }
}
