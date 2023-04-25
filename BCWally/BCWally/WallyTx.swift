import Foundation
@_implementationOnly import CBCWally

public final class WallyTx {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_tx>) {
        self.wrapped = wrapped
    }
    
    public func dispose() {
        wally_tx_free(wrapped)
        wrapped = nil
    }
}

public final class WallyTxInput {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx_input>!
    
    init(wrapped: UnsafeMutablePointer<wally_tx_input>) {
        self.wrapped = wrapped
    }
    
    public func dispose() {
        wally_tx_input_free(wrapped)
        wrapped = nil
    }
}

public final class WallyTxOutput {
    private(set) var wrapped: UnsafeMutablePointer<wally_tx_output>!
    
    init(wrapped: UnsafeMutablePointer<wally_tx_output>) {
        self.wrapped = wrapped
    }
    
    public func dispose() {
        wally_tx_output_free(wrapped)
        wrapped = nil
    }
}

extension Wally {
    public static func txFromBytes(_ data: Data) -> WallyTx? {
        var newTx: UnsafeMutablePointer<wally_tx>!
        let result = data.withUnsafeByteBuffer { buf in
            wally_tx_from_bytes(buf.baseAddress, buf.count, UInt32(WALLY_TX_FLAG_USE_WITNESS), &newTx)
        }
        guard result == WALLY_OK else {
            return nil
        }
        return WallyTx(newTx)
    }
    
    public static func txSetInputScript(tx: WallyTx, index: Int, script: Data) {
        script.withUnsafeByteBuffer {
            precondition(wally_tx_set_input_script(tx.wrapped, index, $0.baseAddress, $0.count) == WALLY_OK)
        }
    }
    
    public static func txAddInput(tx: WallyTx, input: WallyTxInput) {
        precondition(wally_tx_add_input(tx.wrapped, input.wrapped) == WALLY_OK)
    }
    
    public static func txAddOutput(tx: WallyTx, output: WallyTxOutput) {
        precondition(wally_tx_add_output(tx.wrapped, output.wrapped) == WALLY_OK)
    }
    
    public static func txToHex(tx: WallyTx) -> String {
        var output: UnsafeMutablePointer<Int8>!
        defer {
            wally_free_string(output)
        }
        
        precondition(wally_tx_to_hex(tx.wrapped, UInt32(WALLY_TX_FLAG_USE_WITNESS), &output) == WALLY_OK)
        return String(cString: output!)
    }
    
    public static func txGetTotalOutputSatoshi(tx: WallyTx) -> UInt64 {
        var value_out: UInt64 = 0
        precondition(wally_tx_get_total_output_satoshi(tx.wrapped, &value_out) == WALLY_OK)
        return value_out
    }
    
    public static func txGetVsize(tx: WallyTx) -> Int {
        var value_out = 0
        precondition(wally_tx_get_vsize(tx.wrapped, &value_out) == WALLY_OK)
        return value_out
    }
    
    public static func txGetBTCSignatureHash(tx: WallyTx, index: Int, script: Data, amount: UInt64, isWitness: Bool) -> Data {
        script.withUnsafeByteBuffer { buf in
            var message_bytes = [UInt8](repeating: 0, count: Int(SHA256_LEN))
            precondition(wally_tx_get_btc_signature_hash(tx.wrapped, index, buf.baseAddress, buf.count, amount, UInt32(WALLY_SIGHASH_ALL), isWitness ? UInt32(WALLY_TX_FLAG_USE_WITNESS) : 0, &message_bytes, Int(SHA256_LEN)) == WALLY_OK)
            return Data(message_bytes)
        }
    }
}
