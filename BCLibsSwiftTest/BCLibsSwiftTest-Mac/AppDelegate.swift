//
//  AppDelegate.swift
//  BCLibsSwiftTest-Mac
//
//  Created by Wolf McNally on 10/17/20.
//

import Cocoa
import SwiftUI

import CryptoBase
import BIP39
import Shamir
import SSKR

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        assert(CryptoBase.identify() == "CryptoBase")
        assert(BIP39.identify() == "BIP39")
        assert(Shamir.identify() == "Shamir")
        assert(SSKR.identify() == "SSKR")

        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

