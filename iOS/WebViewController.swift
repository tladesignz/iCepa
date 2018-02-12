//
//  WebViewController.swift
//  iCepa-iOS
//
//  Created by Benjamin Erhart on 09.02.18.
//  Copyright © 2018 Conrad Kramer. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKUIDelegate {

    private static let url = URL(string: "https://check.torproject.org")!

    var webView: WKWebView!

    override func loadView() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.uiDelegate = self
        view = webView

        navigationItem.title = WebViewController.url.absoluteString
        navigationItem.setRightBarButton(
            UIBarButtonItem(title: "Reload", style: .plain, target: self, action: #selector(reload)),
            animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        reload()
    }

    @objc func reload() {
        webView.load(URLRequest(url: WebViewController.url))
    }
}
