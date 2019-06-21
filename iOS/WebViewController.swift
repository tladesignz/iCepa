//
//  WebViewController.swift
//  iCepa-iOS
//
//  Created by Benjamin Erhart on 09.02.18.
//  Copyright © 2018 Conrad Kramer. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKUIDelegate, UITextFieldDelegate, WKNavigationDelegate, UIWebViewDelegate {

    private static let url = "https://check.torproject.org"

    private static let useWKWebView = false

    var urlTF: UITextField!

    override func loadView() {
        if WebViewController.useWKWebView {
            let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
            webView.uiDelegate = self
            webView.navigationDelegate = self

            view = webView
        }
        else {
            let webView = UIWebView(frame: .zero)
            webView.delegate = self

            view = webView
        }

        urlTF = UITextField(frame: CGRect(x: 20, y: 100, width: 280, height: 31))
        urlTF.text = WebViewController.url
        urlTF.placeholder = "URL"
        urlTF.borderStyle = .roundedRect
        urlTF.clearButtonMode = .whileEditing
        urlTF.autocapitalizationType = .none
        urlTF.returnKeyType = .go
        urlTF.keyboardType = .URL
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
        view.isHidden = true

        if let string = string, let url = URL(string: string) {
            if let webView = view as? WKWebView {
                webView.load(URLRequest(url: url))
            }
            else if let webView = view as? UIWebView {
                webView.loadRequest(URLRequest(url: url))
            }
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

    // MARK: UIWebViewDelegate

    public func webViewDidFinishLoad(_ webView: UIWebView) {
        webView.isHidden = false
    }

    public func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        alert(error.localizedDescription)
    }

    // MARK: Private methods

    private func alert(_ message: String) {
        NSLog(message)

        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
