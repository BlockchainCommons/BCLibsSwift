import Foundation
@_implementationOnly import CBCWally

public struct WallyExtKey {
    var wrapped: ext_key
    
    init() {
        wrapped = .init()
    }
}

extension Wally {
    public static func key(from parentKey: WallyExtKey, childNum: UInt32, isPrivate: Bool) -> WallyExtKey? {
        withUnsafePointer(to: parentKey.wrapped) { parentPointer in
            let flags = UInt32(isPrivate ? BIP32_FLAG_KEY_PRIVATE : BIP32_FLAG_KEY_PUBLIC)
            var derivedKey = WallyExtKey()
            guard bip32_key_from_parent(parentPointer, childNum, flags, &derivedKey.wrapped) == WALLY_OK else {
                return nil
            }
            return derivedKey
        }
    }

    public static func fingerprintData(for key: WallyExtKey) -> Data {
        // This doesn't work with a non-derivable key, because LibWally thinks it's invalid.
        //var bytes = [UInt8](repeating: 0, count: Int(BIP32_KEY_FINGERPRINT_LEN))
        //precondition(bip32_key_get_fingerprint(&hdkey, &bytes, bytes.count) == WALLY_OK)
        //return Data(bytes)

        hash160(key.wrapped.pub_key).prefix(Int(BIP32_KEY_FINGERPRINT_LEN))
    }

    public static func fingerprint(for key: WallyExtKey) -> UInt32 {
        deserialize(UInt32.self, fingerprintData(for: key))!
    }

    public static func updateHash160(in key: inout WallyExtKey) {
        let hash160Size = MemoryLayout.size(ofValue: key.wrapped.hash160)
        withUnsafeByteBuffer(of: key.wrapped.pub_key) { pub_key in
            withUnsafeMutableByteBuffer(of: &key.wrapped.hash160) { hash160 in
                precondition(wally_hash160(
                    pub_key.baseAddress!, Int(EC_PUBLIC_KEY_LEN),
                    hash160.baseAddress!, hash160Size
                ) == WALLY_OK)
            }
        }
    }

    public static func updatePublicKey(in key: inout WallyExtKey) {
        withUnsafeByteBuffer(of: key.wrapped.priv_key) { priv_key in
            withUnsafeMutableByteBuffer(of: &key.wrapped.pub_key) { pub_key in
                precondition(wally_ec_public_key_from_private_key(
                    priv_key.baseAddress! + 1, Int(EC_PRIVATE_KEY_LEN),
                    pub_key.baseAddress!, Int(EC_PUBLIC_KEY_LEN)
                ) == WALLY_OK)
            }
        }
    }
}

extension Wally {
    public static func hdKey(bip39Seed: Data, network: Network) -> WallyExtKey? {
        let flags = network.wallyBIP32Version(isPrivate: true)
        var key = WallyExtKey()
        let result = bip39Seed.withUnsafeByteBuffer { buf in
            bip32_key_from_seed(buf.baseAddress, buf.count, flags, 0, &key.wrapped)
        }
        guard result == WALLY_OK else {
            return nil
        }
        return key
    }
    
    public static func hdKey(fromBase58 base58: String) -> WallyExtKey? {
        var result = WallyExtKey()
        guard bip32_key_from_base58(base58, &result.wrapped) == WALLY_OK else {
            return nil
        }
        return result
    }
}

extension WallyExtKey: CustomStringConvertible {
    public var description: String {
        let chain_code = Data(of: self.wrapped.chain_code).hex
        let parent160 = Data(of: self.wrapped.parent160).hex
        let depth = self.wrapped.depth
        let priv_key = Data(of: self.wrapped.priv_key).hex
        let child_num = self.wrapped.child_num
        let hash160 = Data(of: self.wrapped.hash160).hex
        let version = self.wrapped.version
        let pub_key = Data(of: self.wrapped.pub_key).hex

        return "WallyExtKey(chain_code: \(chain_code), parent160: \(parent160), depth: \(depth), priv_key: \(priv_key), child_num: \(child_num), hash160: \(hash160), version: \(version), pub_key: \(pub_key))"
    }

    public var isPrivate: Bool {
        wrapped.priv_key.0 == BIP32_FLAG_KEY_PRIVATE
    }

    public var isMaster: Bool {
        wrapped.depth == 0
    }

    public static func version_is_valid(ver: UInt32, flags: UInt32) -> Bool
    {
        if ver == BIP32_VER_MAIN_PRIVATE || ver == BIP32_VER_TEST_PRIVATE {
            return true
        }

        return flags == BIP32_FLAG_KEY_PUBLIC &&
               (ver == BIP32_VER_MAIN_PUBLIC || ver == BIP32_VER_TEST_PUBLIC)
    }

    public func checkValid() {
        let ver_flags = isPrivate ? UInt32(BIP32_FLAG_KEY_PRIVATE) : UInt32(BIP32_FLAG_KEY_PUBLIC)
        precondition(Self.version_is_valid(ver: wrapped.version, flags: ver_flags))
        //precondition(!Data(of: chain_code).isAllZero)
        precondition(wrapped.pub_key.0 == 0x2 || wrapped.pub_key.0 == 0x3)
        precondition(!Data(of: wrapped.pub_key).dropFirst().isAllZero)
        precondition(wrapped.priv_key.0 == BIP32_FLAG_KEY_PUBLIC || wrapped.priv_key.0 == BIP32_FLAG_KEY_PRIVATE)
        precondition(!isPrivate || !Data(of: wrapped.priv_key).dropFirst().isAllZero)
        precondition(!isMaster || Data(of: wrapped.parent160).isAllZero)
    }

    public var network: Network? {
        switch wrapped.version {
        case UInt32(BIP32_VER_MAIN_PRIVATE), UInt32(BIP32_VER_MAIN_PUBLIC):
            return .mainnet
        case UInt32(BIP32_VER_TEST_PRIVATE), UInt32(BIP32_VER_TEST_PUBLIC):
            return .testnet
        default:
            return nil
        }
    }
}
