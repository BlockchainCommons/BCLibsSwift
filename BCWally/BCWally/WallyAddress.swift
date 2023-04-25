import Foundation
@_implementationOnly import CBCWally

extension Wally {
    public static func address(from script: Data, network: Network) -> String {
        var output: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(output)
        }
        script.withUnsafeByteBuffer { buf in
            precondition(wally_scriptpubkey_to_address(buf.baseAddress, buf.count, network.wallyNetwork, &output) == WALLY_OK)
        }
        precondition(output != nil)
        return String(cString: output!)
    }

    public static func segwitAddress(from script: Data, network: Network) -> String {
        var output: UnsafeMutablePointer<Int8>!
        defer {
            wally_free_string(output)
        }
        script.withUnsafeByteBuffer { buf in
            precondition(wally_addr_segwit_from_bytes(buf.baseAddress, buf.count, network.segwitFamily, 0, &output) == WALLY_OK)
        }
        return String(cString: output)
    }
}
