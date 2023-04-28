import Foundation
@_implementationOnly import CBCWally

public extension Wally {
    static func address(from script: Data, network: Network) -> String {
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
    
    static func segwitAddress(from script: Data, network: Network) -> String {
        var output: UnsafeMutablePointer<Int8>!
        defer {
            wally_free_string(output)
        }
        script.withUnsafeByteBuffer { buf in
            precondition(wally_addr_segwit_from_bytes(buf.baseAddress, buf.count, network.segwitFamily, 0, &output) == WALLY_OK)
        }
        return String(cString: output)
    }
    
    enum AddressType {
        case payToPubKeyHash // P2PKH (legacy)
        case payToScriptHashPayToWitnessPubKeyHash // P2SH-P2WPKH (wrapped SegWit)
        case payToWitnessPubKeyHash // P2WPKH (native SegWit)

        var wallyType: UInt32 {
            switch self {
            case .payToPubKeyHash:
                return UInt32(WALLY_ADDRESS_TYPE_P2PKH)
            case .payToScriptHashPayToWitnessPubKeyHash:
                return UInt32(WALLY_ADDRESS_TYPE_P2SH_P2WPKH)
            case .payToWitnessPubKeyHash:
                return UInt32(WALLY_ADDRESS_TYPE_P2WPKH)
            }
        }
    }
    
    static func hdKeyToAddress(hdKey: WallyExtKey, network: Network, type: AddressType) -> String {
        var output: UnsafeMutablePointer<Int8>!
        defer {
            wally_free_string(output)
        }
        
        switch type {
        case .payToPubKeyHash, .payToScriptHashPayToWitnessPubKeyHash:
            var version: UInt32
            switch network {
            case .mainnet:
                version = type == .payToPubKeyHash ? 0x00 : 0x05
            case .testnet:
                version = type == .payToPubKeyHash ? 0x6F : 0xC4
            }
            var key = hdKey.wrapped
            precondition(wally_bip32_key_to_address(&key, type.wallyType, version, &output) == WALLY_OK)
        case .payToWitnessPubKeyHash:
            var key = hdKey.wrapped
            precondition(wally_bip32_key_to_addr_segwit(&key, network.segwitFamily, 0, &output) == WALLY_OK)
        }
        
        return String(cString: output)
    }
}
