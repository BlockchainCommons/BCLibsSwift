import Foundation
@_implementationOnly import CBCWally

public final class WallyPSBT {
    private(set) var wrapped: UnsafeMutablePointer<wally_psbt>!
    
    init(_ wrapped: UnsafeMutablePointer<wally_psbt>) {
        self.wrapped = wrapped
    }
    
    public func dispose() {
        wally_psbt_free(wrapped)
        wrapped = nil
    }
}

public struct WallyPSBTInput {
    var wrapped: wally_psbt_input
    
    init() {
        wrapped = .init()
    }
}

public struct WallyPSBTOutput {
    var wrapped: wally_psbt_output
    
    init() {
        wrapped = .init()
    }
}

extension Wally {
    public static func psbt(from data: Data) -> WallyPSBT? {
        data.withUnsafeByteBuffer { bytes in
            var p: UnsafeMutablePointer<wally_psbt>!
            guard wally_psbt_from_bytes(bytes.baseAddress!, data.count, 0, &p) == WALLY_OK else {
                return nil
            }
            return WallyPSBT(p)
        }
    }
    
    public static func clone(psbt: WallyPSBT) -> WallyPSBT {
        var new_psbt: UnsafeMutablePointer<wally_psbt>!
        precondition(wally_psbt_clone_alloc(psbt.wrapped, 0, &new_psbt) == WALLY_OK)
        return WallyPSBT(new_psbt)
    }
    
    public static func isFinalized(psbt: WallyPSBT) -> Bool {
        var result = 0
        precondition(wally_psbt_is_finalized(psbt.wrapped, &result) == WALLY_OK)
        return result != 0
    }
    
    public static func finalized(psbt: WallyPSBT) -> WallyPSBT? {
        let final = copy(psbt: psbt)
        guard wally_psbt_finalize(final.wrapped, 0) == WALLY_OK else {
            return nil
        }
        return final
    }

    public static func finalizedPSBT(psbt: WallyPSBT) -> WallyTx? {
        var output: UnsafeMutablePointer<wally_tx>!
        guard wally_psbt_extract(psbt.wrapped, 0, &output) == WALLY_OK else {
            return nil
        }
        return WallyTx(output)
    }
    
    public static func getLength(psbt: WallyPSBT) -> Int {
        var len = 0
        precondition(wally_psbt_get_length(psbt.wrapped, 0, &len) == WALLY_OK)
        return len
    }
    
    public static func serialized(psbt: WallyPSBT) -> Data {
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
    
    public static func signed(psbt: WallyPSBT, ecPrivateKey: Data) -> WallyPSBT? {
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
