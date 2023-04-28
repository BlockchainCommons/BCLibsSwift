import Foundation
@_implementationOnly import CBCWally

public final class WallyPSBT {
    private(set) var wrapped: UnsafeMutablePointer<wally_psbt>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_psbt>) {
        self.wrapped = wrapped
    }
    
    public var tx: WallyTx {
        WallyTx(wrapped.pointee.tx)
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
    
    public func input(at index: Int) -> WallyPSBTInput {
        WallyPSBTInput(&wrapped.pointee.inputs[index])
    }
    
    public func output(at index: Int) -> WallyPSBTOutput {
        WallyPSBTOutput(&wrapped.pointee.outputs[index])
    }
    
    public func clone() -> WallyPSBT {
        var new_psbt: UnsafeMutablePointer<wally_psbt>!
        precondition(wally_psbt_clone_alloc(wrapped, 0, &new_psbt) == WALLY_OK)
        return WallyPSBT(new_psbt)
    }

    public func dispose() {
        wally_psbt_free(wrapped)
        wrapped = nil
    }
}

public final class WallyPSBTInput {
    private(set) var wrapped: UnsafeMutablePointer<wally_psbt_input>
    
    init(_ wrapped: UnsafeMutablePointer<wally_psbt_input>) {
        self.wrapped = wrapped
    }
    
    public var keyPaths: WallyMap {
        WallyMap(&wrapped.pointee.keypaths)
    }
    
    public var signatures: WallyMap {
        WallyMap(&wrapped.pointee.signatures)
    }
    
    public var finalWitness: WallyWitnessStack? {
        guard let final_witness = wrapped.pointee.final_witness else {
            return nil
        }
        return WallyWitnessStack(final_witness)
    }
    
    public var witnessUTXO: WallyTxOutput? {
        guard let witness_utxo = wrapped.pointee.witness_utxo else {
            return nil
        }
        return WallyTxOutput(witness_utxo)
    }
}

public final class WallyPSBTOutput {
    private(set) var wrapped: UnsafeMutablePointer<wally_psbt_output>
    
    init(_ wrapped: UnsafeMutablePointer<wally_psbt_output>) {
        self.wrapped = wrapped
    }
    
    public var keyPaths: WallyMap {
        WallyMap(&wrapped.pointee.keypaths)
    }
    
    public var script: Data? {
        guard wrapped.pointee.script_len > 0 else {
            return nil
        }
        return Data(bytes: wrapped.pointee.script, count: wrapped.pointee.script_len)
    }
}

public extension Wally {
    static func psbt(from data: Data) -> WallyPSBT? {
        data.withUnsafeByteBuffer { bytes in
            var p: UnsafeMutablePointer<wally_psbt>!
            guard wally_psbt_from_bytes(bytes.baseAddress!, data.count, 0, &p) == WALLY_OK else {
                return nil
            }
            return WallyPSBT(p)
        }
    }
    
    static func isFinalized(psbt: WallyPSBT) -> Bool {
        var result = 0
        precondition(wally_psbt_is_finalized(psbt.wrapped, &result) == WALLY_OK)
        return result != 0
    }
    
    static func finalized(psbt: WallyPSBT) -> WallyPSBT? {
        let final = copy(psbt: psbt)
        guard wally_psbt_finalize(final.wrapped, 0) == WALLY_OK else {
            return nil
        }
        return final
    }

    static func finalizedPSBT(psbt: WallyPSBT) -> WallyTx? {
        var output: UnsafeMutablePointer<wally_tx>!
        guard wally_psbt_extract(psbt.wrapped, 0, &output) == WALLY_OK else {
            return nil
        }
        return WallyTx(output)
    }
    
    static func getLength(psbt: WallyPSBT) -> Int {
        var len = 0
        precondition(wally_psbt_get_length(psbt.wrapped, 0, &len) == WALLY_OK)
        return len
    }
    
    static func serialized(psbt: WallyPSBT) -> Data {
        let len = getLength(psbt: psbt)
        var result = Data(count: len)
        result.withUnsafeMutableBytes {
            var written = 0
            precondition(wally_psbt_to_bytes(psbt.wrapped, 0, $0.bindMemory(to: UInt8.self).baseAddress!, len, &written) == WALLY_OK)
            precondition(written == len)
        }
        return result
    }
    
    private static func copy(psbt: WallyPSBT) -> WallyPSBT {
        let data = serialized(psbt: psbt)
        return Self.psbt(from: data)!
    }
    
    static func signed(psbt: WallyPSBT, ecPrivateKey: Data) -> WallyPSBT? {
        ecPrivateKey.withUnsafeByteBuffer { keyBytes in
            let signedPSBT = copy(psbt: psbt)
            let ret = wally_psbt_sign(signedPSBT.wrapped, keyBytes.baseAddress, keyBytes.count, 0)
            guard ret == WALLY_OK else {
                return nil
            }
            return signedPSBT
        }
    }
}
