import Foundation
@_implementationOnly import CBCWally

extension Wally {
    public static func getScriptType(from script: Data) -> Int {
        var output = 0
        script.withUnsafeByteBuffer { buf in
            precondition(wally_scriptpubkey_get_type(buf.baseAddress, buf.count, &output) == WALLY_OK)
        }
        return output
    }
    
    public static func multisigScriptPubKey(pubKeys: [Data], threshold: UInt, isBIP67: Bool = true) -> Data {
        var pubkeys_bytes = Data()
        for pubKey in pubKeys {
            pubkeys_bytes.append(pubKey)
        }
        let scriptLen = 3 + pubKeys.count * (Int(EC_PUBLIC_KEY_LEN) + 1)
        var script_bytes = [UInt8](repeating: 0, count: scriptLen)
        let flags = UInt32(isBIP67 ? WALLY_SCRIPT_MULTISIG_SORTED : 0)
        var written = 0
        pubkeys_bytes.withUnsafeByteBuffer { buf in
            precondition(wally_scriptpubkey_multisig_from_bytes(buf.baseAddress, buf.count, UInt32(threshold), flags, &script_bytes, scriptLen, &written) == WALLY_OK)
        }
        return Data(bytes: script_bytes, count: written)
    }

    public static func witnessProgram(from script: Data) -> Data {
        var script_bytes = [UInt8](repeating: 0, count: 34) // 00 20 HASH256
        var written = 0
        script.withUnsafeByteBuffer { buf in
            precondition(wally_witness_program_from_bytes(buf.baseAddress, buf.count, UInt32(WALLY_SCRIPT_SHA256), &script_bytes, script_bytes.count, &written) == WALLY_OK)
            precondition(written == script_bytes.count)
        }
        return Data(script_bytes)
    }
    
    public static func addressToScript(address: String, network: Network) -> Data? {
        // base58 and bech32 use more bytes in string form, so description.count should be safe:
        var bytes_out = [UInt8](repeating: 0, count: address.count)
        var written = 0
        guard wally_address_to_scriptpubkey(address, network.wallyNetwork, &bytes_out, address.count, &written) == WALLY_OK else {
            return nil
        }
        return Data(bytes: bytes_out, count: written)
    }

    public static func segwitAddressToScript(address: String, network: Network) -> Data? {
        // base58 and bech32 use more bytes in string form, so description.count should be safe:
        var bytes_out = [UInt8](repeating: 0, count: address.count)
        var written = 0
        guard wally_addr_segwit_to_bytes(address, network.segwitFamily, 0, &bytes_out, address.count, &written) == WALLY_OK else {
            return nil
        }
        return Data(bytes: bytes_out, count: written)
    }
}
