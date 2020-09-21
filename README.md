# 📚 BCLibsSwift

Blockchain Commons publishes several open source C libraries that are useful in cryptocurrency wallets. This project wraps some of those libraries in opinionated Swift frameworks that work across iOS devices, the iOS simulator, and Mac Catalyst builds.

The build script currently produces these frameworks:

* `CCryptoBase.xcframework` based on [bc-crypto-base](https://github.com/blockchaincommons/bc-crypto-base)
* `CShamir.xcframework` based on [bc-shamir](https://github.com/blockchaincommons/bc-shamir)
* `CSSKR.xcframework` based on [bc-sskr](https://github.com/blockchaincommons/bc-sskr)
* `CryptoBase.xcframework`
* `Shamir.xcframework`
* `SSKR.xcframework`

The frameworks that have the "C" prefix wrap the C libraries themselves. The ones without the prefix contain Swifty interfaces to the C libraries.

The C libraries have each other as dependencies, so to use any of these frameworks you must include it and any of its dependencies.

* `CCryptoCase` has no dependencies
* `CShamir` depends on `CCryptoBase`
* `CSSKR` depends on `CShamir` and `CCryptoBase`

If you want to use one of the Swift frameworks you'll need to include the corresponding C framework and all the C frameworks it depends on in your Xcode project. So if you just want to include the SSKR functionality, you'll need:

* `CCryptoBase`
* `CShamir`
* `CSSKR`
* `SSKR`

## Build

```
$ git clone https://github.com/blockchaincommons/BCLibsSwift.git
$ cd BCLibsSwift
$ ./build.sh
```

The resulting frameworks are in `BCLibsSwift/build/`.

## Usage

To use one of the Swift frameworks, include the necessary frameworks as above, and import the API you want to use in your code:

```
import SSKR
```

For examples of usage, open `BCLibsSwift.xcworkspace` and examine the unit test targets `CryptoBaseTests`, `ShamirTests`, and `SSKRTests`. These unit tests may be run only after running the `build.sh` script.
