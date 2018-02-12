//
//  WebViewController.swift
//  iCepa-iOS
//
//  Created by Benjamin Erhart on 09.02.18.
//  Copyright © 2018 Conrad Kramer. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKUIDelegate, UITextFieldDelegate, WKNavigationDelegate {

    private static let url = "https://check.torproject.org"

    var webView: WKWebView!
    var urlTF: UITextField!

    override func loadView() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView

        urlTF = UITextField(frame: CGRect(x: 20, y: 100, width: 280, height: 31))
        urlTF.text = WebViewController.url
        urlTF.placeholder = "URL"
        urlTF.borderStyle = .roundedRect
        urlTF.clearButtonMode = .whileEditing
        urlTF.autocapitalizationType = .none
        urlTF.returnKeyType = .go
        urlTF.delegate = self

        navigationItem.setRightBarButton(
            UIBarButtonItem(customView: urlTF),
            animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        view.window?.backgroundColor = UIColor.white

        load()
    }

    func load(_ string: String?) {
        webView.isHidden = true

        if let string = string, let url = URL(string: string) {
            webView.load(URLRequest(url: url))
        }
        else {
            alert("Invalid URL.")
        }
    }

    func load() {
        load(WebViewController.url)
    }

    // MARK: UITextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        load(textField.text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        alert(error.localizedDescription)
    }


    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        alert(error.localizedDescription)
    }

    private func alert(_ message: String) {
        NSLog(message)

        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
