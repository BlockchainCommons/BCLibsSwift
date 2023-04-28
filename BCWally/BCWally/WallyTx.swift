import Foundation
@_implementationOnly import CBCWally

public final class WallyTx {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_tx>) {
        self.wrapped = wrapped
    }
    
    public convenience init(version: UInt32, lockTime: UInt32, inputs: [WallyTxInput], outputs: [WallyTxOutput]) {
        var wtx: UnsafeMutablePointer<wally_tx>!
        precondition(wally_tx_init_alloc(version, lockTime, inputs.count, outputs.count, &wtx) == WALLY_OK)
        for input in inputs {
            precondition(wally_tx_add_input(wtx, input.wrapped) == WALLY_OK)
        }
        for output in outputs {
            precondition(wally_tx_add_output(wtx, output.wrapped) == WALLY_OK)
        }
        self.init(wtx)
    }
    
    public func setInputWitness(index: Int, stack: WallyWitnessStack) {
        precondition(wally_tx_set_input_witness(self.wrapped, index, stack.wrapped) == WALLY_OK)
    }
    
    public func setInputScript(index: Int, script: Data) {
        script.withUnsafeByteBuffer {
            precondition(wally_tx_set_input_script(wrapped, index, $0.baseAddress, $0.count) == WALLY_OK)
        }
    }
    
    public var version: UInt32 {
        wrapped.pointee.version
    }

    public var inputsCount: Int {
        wrapped.pointee.num_inputs
    }
    
    public var outputsCount: Int {
        wrapped.pointee.num_outputs
    }
    
    public var inputsAllocationCount: Int {
        wrapped.pointee.inputs_allocation_len
    }
    
    public var outputsAllocationCount: Int {
        wrapped.pointee.outputs_allocation_len
    }
    
    public func input(at index: Int) -> WallyTxInput {
        WallyTxInput(&wrapped.pointee.inputs[index])
    }
    
    public func output(at index: Int) -> WallyTxOutput {
        WallyTxOutput(&wrapped.pointee.outputs[index])
    }
    
    public func clone() -> WallyTx {
        var newTx: UnsafeMutablePointer<wally_tx>!
        precondition(wally_tx_clone_alloc(self.wrapped, 0, &newTx) == WALLY_OK)
        return WallyTx(newTx)
    }
   
    public func dispose() {
        wally_tx_free(wrapped)
        wrapped = nil
    }
}

public final class WallyTxInput {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx_input>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_tx_input>) {
        self.wrapped = wrapped
    }
    
    public convenience init(prevTx: Data, vout: UInt32, sequence: UInt32, amount: UInt64, witness: WallyWitnessStack?) {
        self.init(prevTx.withUnsafeByteBuffer { prevTxBytes in
            var wti: UnsafeMutablePointer<wally_tx_input>!
            precondition(wally_tx_input_init_alloc(prevTxBytes.baseAddress, prevTxBytes.count, vout, sequence, nil, 0, witness?.wrapped, &wti) == WALLY_OK)
            return wti
        })
    }
    
    public func dispose() {
        wally_tx_input_free(wrapped)
        wrapped = nil
    }
}

public final class WallyTxOutput {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx_output>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_tx_output>) {
        self.wrapped = wrapped
    }
    
    public convenience init(amount: UInt64, scriptPubKey: Data) {
        self.init(scriptPubKey.withUnsafeByteBuffer { scriptPubKeyBytes in
            var output: UnsafeMutablePointer<wally_tx_output>!
            precondition(wally_tx_output_init_alloc(amount, scriptPubKeyBytes.baseAddress, scriptPubKeyBytes.count, &output) == WALLY_OK)
            return output
        })
    }
    
    public var satoshi: UInt64 {
        return wrapped.pointee.satoshi
    }
    
    public var script: Data {
        precondition(wrapped.pointee.script_len > 0)
        return Data(bytes: wrapped.pointee.script, count: wrapped.pointee.script_len)
    }
    
    public func dispose() {
        wally_tx_output_free(wrapped)
        wrapped = nil
    }
}

public extension Wally {
    static func txFromBytes(_ data: Data) -> WallyTx? {
        var newTx: UnsafeMutablePointer<wally_tx>!
        let result = data.withUnsafeByteBuffer { buf in
            wally_tx_from_bytes(buf.baseAddress, buf.count, UInt32(WALLY_TX_FLAG_USE_WITNESS), &newTx)
        }
        guard result == WALLY_OK else {
            return nil
        }
        return WallyTx(newTx)
    }
    
    static func txToHex(tx: WallyTx) -> String {
        var output: UnsafeMutablePointer<Int8>!
        defer {
            wally_free_string(output)
        }
        
        precondition(wally_tx_to_hex(tx.wrapped, UInt32(WALLY_TX_FLAG_USE_WITNESS), &output) == WALLY_OK)
        return String(cString: output!)
    }
    
    static func txGetTotalOutputSatoshi(tx: WallyTx) -> UInt64 {
        var value_out: UInt64 = 0
        precondition(wally_tx_get_total_output_satoshi(tx.wrapped, &value_out) == WALLY_OK)
        return value_out
    }
    
    static func txGetVsize(tx: WallyTx) -> Int {
        var value_out = 0
        precondition(wally_tx_get_vsize(tx.wrapped, &value_out) == WALLY_OK)
        return value_out
    }
    
    static func txGetBTCSignatureHash(tx: WallyTx, index: Int, script: Data, amount: UInt64, isWitness: Bool) -> Data {
        script.withUnsafeByteBuffer { buf in
            var message_bytes = [UInt8](repeating: 0, count: Int(SHA256_LEN))
            precondition(wally_tx_get_btc_signature_hash(tx.wrapped, index, buf.baseAddress, buf.count, amount, UInt32(WALLY_SIGHASH_ALL), isWitness ? UInt32(WALLY_TX_FLAG_USE_WITNESS) : 0, &message_bytes, Int(SHA256_LEN)) == WALLY_OK)
            return Data(message_bytes)
        }
    }
}
