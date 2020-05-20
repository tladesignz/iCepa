//
//  MyTorThread.swift
//  iCepa
//
//  Created by Benjamin Erhart on 12.02.18.
//  Copyright © 2018 Conrad Kramer. All rights reserved.
//

import Foundation

class MyTorThread: TorThread {

    static let configuration: TorConfiguration = {
        let dataDirectory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: CPAAppGroupIdentifier)?
            .appendingPathComponent("Tor")

        let configuration = TorConfiguration()
        configuration.options = ["DNSPort": "12345",
                                 "AutomapHostsOnResolve": "1",
                                 "SocksPort": "9050",
                                 "AvoidDiskWrites": "1"]
        configuration.cookieAuthentication = true
        configuration.dataDirectory = dataDirectory
        configuration.controlSocket = dataDirectory?.appendingPathComponent("control_port")
        configuration.arguments = ["--ignore-missing-torrc"]
        
        return configuration
    }()

    convenience init() {
        MyTorThread.purgeDataDirectory()

        self.init(configuration: MyTorThread.configuration)
    }

    static func purgeDataDirectory() {
        // This is needed because tor loads its cache too aggressively for Jetsam
        if let dataDirectory = MyTorThread.configuration.dataDirectory {
            let fm = FileManager.default
            try? fm.removeItem(at: dataDirectory)

            do {
                try fm.createDirectory(at: dataDirectory,
                                       withIntermediateDirectories: true,
                                       attributes: [FileAttributeKey(rawValue: FileAttributeKey.posixPermissions.rawValue): 0o700])
            } catch let error as NSError {
                NSLog("Error: Cannot configure data directory: \(error.localizedDescription)")
            }
        }
        else {
            NSLog("Error: Tor data directory in shared group folder not available! This will not work!")
        }
    }
}
