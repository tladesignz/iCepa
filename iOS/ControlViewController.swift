//
//  ControlViewController.swift
//  iCepa
//
//  Created by Conrad Kramer on 9/25/15.
//  Copyright © 2015 Conrad Kramer. All rights reserved.
//

import UIKit
import NetworkExtension

class ControlViewController: UIViewController {
    
    let manager: NETunnelProviderManager
    let session: NETunnelProviderSession

    weak var startStopButton: FloatingButton?
    weak var establishedLabel: UILabel?
    var torThreadStyle: UISegmentedControl!

    private static let torThread: MyTorThread = {
        return MyTorThread()
    }()

    required init(manager: NETunnelProviderManager) {
        self.manager = manager
        session = manager.connection as! NETunnelProviderSession

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(statusDidChange), name: .NEVPNStatusDidChange, object: nil)
    }
    
    override func loadView() {
        super.loadView()
        
        view.backgroundColor = UIColor.white
        
        let button = FloatingButton()
        button.addTarget(self, action: #selector(enableStartStop), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.gradient = (UIColor(rgbaValue: 0x00CD86FF), UIColor(rgbaValue: 0x3AB52AFF))
        view.addSubview(button)
        self.startStopButton = button
        
        let label = UILabel(frame: CGRect.zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        self.establishedLabel = label

        statusDidChange(nil)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 180),
            button.heightAnchor.constraint(equalToConstant: 50),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            NSLayoutConstraint(item: label, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 0.5, constant: 0)
            ])

        torThreadStyle = UISegmentedControl(items: ["NE", "App"])
        torThreadStyle.selectedSegmentIndex = 0
        navigationItem.setLeftBarButton(UIBarButtonItem(customView: torThreadStyle!), animated: false)

        navigationItem.title = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""

        navigationItem.setRightBarButton(
            UIBarButtonItem(title: "Test", style: .plain, target: self, action: #selector(gotoWebView)),
            animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func enableStartStop() {
        let start: (() -> Void) = {
            var delay = DispatchTime.now()

            if self.torThreadStyle?.selectedSegmentIndex == 0 {
                // So the simple test in PacketTunnelProvider, if Tor is already running, works.
                MyTorThread.purgeDataDirectory()
            }
            else {
                if !ControlViewController.torThread.isExecuting {
                    ControlViewController.torThread.start()

                    // Need to wait to start VPN tunnel until after Tor has bootstrapped, otherwise
                    // Tor will get into an infinit loop trying to load the microdescriptors, because
                    // iOS will redirect the traffic to the started Network Extension, which tries to
                    // connect to Tor, which isn't ready, yet...
                    delay = DispatchTime.now() + 20

                    // Fake NE start
                    self.establishedLabel?.text = NSLocalizedString("Waiting for local Tor", comment: "")
                    self.startStopButton?.setTitle(NSLocalizedString("Stop Tor", comment: ""), for: UIControlState())
                }
            }

            DispatchQueue.main.asyncAfter(deadline: delay) {
                do {
                    try self.session.startVPNTunnel()
                } catch let error {
                    return print("Error: Could not start manager: \(error)")
                }

                print("Establish communications channel with extension.")
                self.commTunnel()
            }
        }

        // If there already is a VPN configuration before we came along, that one will be kept
        // selected instead of ours. So we first have to enable ours and then we can start
        // immediately.
        if !manager.isEnabled {
            manager.isEnabled = true
            manager.saveToPreferences() { (error) in
                if let error = error {
                    return print("Error: Could not enable manager: \(error)")
                }
                self.manager.loadFromPreferences() { (error) in
                    if let error = error {
                        return print("Error: Could not reload manager: \(error)")
                    }
                    start()
                }
            }
            return
        }

        switch session.status {
        case .invalid, .disconnecting, .disconnected:
            start()
        default:
            session.stopVPNTunnel()
        }
    }

    @objc func statusDidChange(_ note: Notification?) {
        let labelText: String
        let buttonText: String

        switch session.status {
        case .invalid:
            labelText = NSLocalizedString("Provider not installed/enabled", comment: "")
            buttonText = NSLocalizedString("Enable Provider in Settings!", comment: "")
            self.startStopButton?.isEnabled = false
        case .connecting:
            labelText = NSLocalizedString("Circuit Establishing", comment: "")
            buttonText = NSLocalizedString("Stop Tor", comment: "")
            self.startStopButton?.isEnabled = true
        case .connected:
            labelText = NSLocalizedString("Circuit Established", comment: "")
            buttonText = NSLocalizedString("Stop Tor", comment: "")
            self.startStopButton?.isEnabled = true
        case .reasserting:
            labelText = NSLocalizedString("Circuit Reestablishing", comment: "")
            buttonText = NSLocalizedString("Stop Tor", comment: "")
            self.startStopButton?.isEnabled = true
        case .disconnecting:
            labelText = NSLocalizedString("Circuit Disestablishing", comment: "")
            buttonText = NSLocalizedString("Start Tor", comment: "")
            self.startStopButton?.isEnabled = true
        case .disconnected:
            labelText = NSLocalizedString("Circuit Not Established", comment: "")
            buttonText = NSLocalizedString("Start Tor", comment: "")
            self.startStopButton?.isEnabled = true
        }

        self.establishedLabel?.text = labelText
        self.startStopButton?.setTitle(buttonText, for: UIControlState())

    }

    @objc func gotoWebView() {
        NotificationCenter.default.post(name: AppCoordinator.gotoWebViewNotification, object: nil)
    }

    private func commTunnel() {
        if session.status != .invalid {
            do {
                try session.sendProviderMessage(Data()) { response in
                    if let response = response {
                        if let response = NSKeyedUnarchiver.unarchiveObject(with: response) as? [String: Any] {
                            if let log = response["log"] as? [String] {
                                for line in log {
                                    print(line.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Could not establish communications channel with extension. Error: \(error)")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: self.commTunnel)
        }
        else {
            print("Could not establish communications channel with extension. "
                + "VPN configuration does not exist or is not enabled. "
                + "No further actions will be taken.")
        }
    }
}
