//
//  AppDelegate.swift
//  iCepa
//
//  Created by Conrad Kramer on 10/1/15.
//  Copyright © 2015 Conrad Kramer. All rights reserved.
//

import Cocoa
import NetworkExtension
import Tor

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let start: (NETunnelProviderManager) -> (Void) = { (manager) in
            do {
                try manager.connection.startVPNTunnel()
            } catch let error as NSError {
                NSLog("Error: Could not start manager: %@", error)
            }
            
            let appGroupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CPAAppGroupIdentifier)!
            let dataDirectory = appGroupDirectory.appendingPathComponent("Tor")
            let controlSocket = dataDirectory.appendingPathComponent("control_port")

            
            let controller = TorController(socketURL: controlSocket)
            controller.addObserver(forCircuitEstablished: { (established) in
                
            })
        }

        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let manager = managers?.first {
                if manager.isEnabled {
                    start(manager)
                } else {
                    manager.isEnabled = true
                    manager.saveToPreferences() { error in
                        if let error = error {
                            print("Error: Could not enable manager: \(error)")
                            return
                        }
                        start(manager)
                    }
                }
            }
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}
