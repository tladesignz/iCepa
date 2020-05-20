//
//  PacketTunnelProvider.swift
//  iCepa
//
//  Created by Conrad Kramer on 10/3/15.
//  Copyright © 2015 Conrad Kramer. All rights reserved.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider, URLSessionDelegate {

    private static let ENABLE_LOGGING = true
    private static var messageQueue: [String: Any] = ["log":[]]

    private static let torThread: MyTorThread = {
        return MyTorThread()
    }()

    private var timer: Timer?

    private lazy var tunThread: TunThread? = {
        return TunThread(packetFlow: self.packetFlow)
    }()
    
    private lazy var controller: TorController? = {
        return TorController(socketURL: MyTorThread.configuration.controlSocket!)
    }()

    override var protocolConfiguration: NETunnelProviderProtocol {
        return super.protocolConfiguration as! NETunnelProviderProtocol
    }

    private var hostHandler: ((Data?) -> Void)?

    override func startTunnel(options: [String : NSObject]? = [:], completionHandler: @escaping (Error?) -> Void) {
        print("startTunnel xxx")

        let ipv4Settings = NEIPv4Settings(addresses: ["192.168.20.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]

        log("startTunnel, options: \(String(describing: options))")

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.ipv4Settings = ipv4Settings
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])

        let controller = self.controller
        self.setTunnelNetworkSettings(settings) { (error) -> Void in
            if let error = error {
                self.log("Error cannot set tunnel network settings: \(error.localizedDescription)")
                return completionHandler(error)
            }

            var alreadyRunning = false

            if var lock = MyTorThread.configuration.dataDirectory {
                lock.appendPathComponent("lock")

                alreadyRunning = FileManager.default.fileExists(atPath: lock.path)
            }

            self.log("TorThread is already running: \(alreadyRunning)")

            if !alreadyRunning {
                PacketTunnelProvider.torThread.start()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                do {
                    self.log("startTunnel, before connecting to Tor thread.")

// Use this with a recent Tor.framework to tunnel logs from Tor to the app.
//                    TORInstallTorLoggingCallback { (type: OSLogType, message: UnsafePointer<Int8>) in
//                        PacketTunnelProvider.log(tag: "TOR", String(cString: message))
//                    }
//
//                    self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
//                                                      selector: #selector(self.sendMessages),
//                                                      userInfo: nil, repeats: true)

                    var success: Any?


                    do {
                        success = try controller?.connect()
                    }
                    catch let error as NSError {
                        self.log("Error while controller.connect(): \(error)")
                    }
                    self.log("after controller.connect(), success = \(String(describing: success)) controller=\(String(describing: controller))")

                    let cookie = try Data(contentsOf: MyTorThread.configuration.dataDirectory!.appendingPathComponent("control_auth_cookie"), options: NSData.ReadingOptions(rawValue: 0))

                    self.log("Cookie: \(cookie)")
                    controller?.authenticate(with: cookie, completion: { (success, error) -> Void in
                        if let error = error {
                            self.log("Error: Cannot authenticate with Tor: \(error.localizedDescription)")
                            return completionHandler(error)
                        }
                        
                        var observer: Any? = nil
                        observer = controller?.addObserver(forCircuitEstablished: { (established) -> Void in
                            guard established else {
                                return
                            }
                            
                            controller?.removeObserver(observer)
                            
                            self.tunThread?.start()

                            self.log("startTunnel, tunnel started.")

                            completionHandler(nil)
                        })
                        
                        // TODO: Handle circuit establish failure
                    })
                } catch let error as NSError {
                    self.log("Error: Cannot connect to Tor: \(error.localizedDescription)")
                    completionHandler(nil /* error */)
                }
            }
        }
    }
    
    func stopTunnel(with reason: NEProviderStopReason, completionHandler: () -> Void) {
        log("stopTunnel, reason: \(reason)")

        tunThread = nil
        controller = nil

        self.timer?.invalidate()
        self.timer = nil

        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if PacketTunnelProvider.ENABLE_LOGGING {
            hostHandler = completionHandler
        }
    }

    @objc private func sendMessages() {
        if PacketTunnelProvider.ENABLE_LOGGING, let handler = hostHandler {
            let response = NSKeyedArchiver.archivedData(withRootObject: PacketTunnelProvider.messageQueue)
            PacketTunnelProvider.messageQueue = ["log": []]
            handler(response)
            hostHandler = nil
        }
    }

    private func log(tag: String? = nil, _ message: String) {
        PacketTunnelProvider.log(tag: tag, message)

        sendMessages()
    }

    private static func log(tag: String? = nil, _ message: String) {
        if ENABLE_LOGGING, var log = messageQueue["log"] as? [String] {
            log.append("\(tag ?? String(describing: self)): \(message)")
            messageQueue["log"] = log

            NSLog(message)
        }
    }
}
