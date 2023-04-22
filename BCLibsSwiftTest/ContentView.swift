import SwiftUI
import CryptoBase
import BIP39
import Shamir
import SSKR

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
            testLib(name: "CryptoBase", test: { CryptoBase.identify() })
            testLib(name: "BIP39", test: { BIP39.identify() })
            testLib(name: "Shamir", test: { Shamir.identify() })
            testLib(name: "SSKR", test: { SSKR.identify() })
        }
        .padding()
    }
    
    @ViewBuilder
    func testLib(name: String, test: () -> String) -> some View {
        Group {
            if test() == name {
                Text("\(name): ") + Text("OK").foregroundColor(.green)
            } else {
                Text("\(name): ") + Text("Error").foregroundColor(.red)
            }
        }
        .bold()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
