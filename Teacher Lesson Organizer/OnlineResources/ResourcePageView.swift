import OSLog
import SwiftUI
@preconcurrency import WebKit

struct ResourcePageView: UIViewControllerRepresentable {
    let address: URL?
    let didLoad: (URL) -> Void

    func makeUIViewController(context: Context) -> ResourcePageController {
        ResourcePageController()
    }

    func updateUIViewController(_ controller: ResourcePageController, context: Context) {
        controller.didLoad = didLoad
        if let address {
            controller.display(address)
        }
    }
}

final class ResourcePageController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ResourcePages", category: "WebNavigation")
    private lazy var reader: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        return makePage(configuration)
    }()
    private var tabs: [WKWebView] = []
    var didLoad: ((URL) -> Void)?
    private var initialNavigation: WKNavigation?
    private var loadedAddress: URL?
    private var retryTask: Task<Void, Never>?
    private var networkRetries = 0
    private var processRestarts = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        mount(reader, guide: view.safeAreaLayoutGuide)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var shouldAutorotate: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    func display(_ destination: URL) {
        guard destination != loadedAddress else { return }
        loadViewIfNeeded()
        retryTask?.cancel()
        networkRetries = 0
        loadedAddress = destination
        initialNavigation = reader.load(URLRequest(url: destination))
    }

    func webView(_ surface: WKWebView, didCommit navigation: WKNavigation!) {
        if tabs.contains(surface) {
            // The initial empty document must not cover the opener for an HTTP request.
            if let url = surface.url, url.absoluteString != "about:blank" {
                surface.isHidden = false
            }
            logger.info("New window committed a document")
        }
        guard surface === reader, let navigation, navigation === initialNavigation, let loadedAddress else { return }
        retryTask?.cancel()
        initialNavigation = nil
        didLoad?(loadedAddress)
    }

    func webView(
        _ surface: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if tabs.contains(surface), navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse {
            logger.info("New window received HTTP \(response.statusCode, privacy: .public)")
        }
        decisionHandler(.allow)
    }

    func webView(
        _ surface: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url, opensExternally(url) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ surface: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, opensExternally(url) {
            UIApplication.shared.open(url)
            return nil
        }
        // WebKit loads the request into this view and keeps the opener relationship.
        let page = makePage(configuration)
        page.customUserAgent = surface.customUserAgent
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? "none"
        // Empty windows can be filled directly by the opener, without an HTTP response.
        page.isHidden = scheme == "http" || scheme == "https"
        mount(page, guide: view.safeAreaLayoutGuide)
        tabs.append(page)
        logger.info("Created new window for URL scheme \(scheme, privacy: .public)")
        return page
    }

    func webViewDidClose(_ surface: WKWebView) {
        closeTab(for: surface)
    }

    func webView(
        _ surface: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.prompt)
    }

    private func closeTab(for surface: WKWebView) {
        guard let index = tabs.firstIndex(where: { $0 === surface }) else { return }
        tabs.remove(at: index)
        surface.stopLoading()
        surface.removeFromSuperview()
    }

    func webViewWebContentProcessDidTerminate(_ surface: WKWebView) {
        guard processRestarts < 2 else { return }
        processRestarts += 1
        if let url = surface.url ?? (surface === reader ? loadedAddress : nil) {
            let recovery = surface.load(URLRequest(url: url))
            if surface === reader, initialNavigation != nil { initialNavigation = recovery }
        }
    }

    func webView(_ surface: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handlePopupFailure(error, in: surface)
        recover(surface, from: error, navigation: navigation)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handlePopupFailure(error, in: surface)
        recover(surface, from: error, navigation: navigation)
    }

    private func handlePopupFailure(_ error: Error, in surface: WKWebView) {
        guard tabs.contains(surface) else { return }
        let failure = error as NSError
        guard failure.domain != NSURLErrorDomain || failure.code != NSURLErrorCancelled else { return }
        logger.error("New window navigation failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public)")
        if surface.isHidden {
            closeTab(for: surface)
        }
    }

    private func makePage(_ configuration: WKWebViewConfiguration) -> WKWebView {
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let page = WKWebView(frame: .zero, configuration: configuration)
        page.customUserAgent = ResourceDirectory.pageAgent
        page.navigationDelegate = self
        page.uiDelegate = self
        page.allowsBackForwardNavigationGestures = true
        return page
    }

    private func mount(_ child: UIView, guide: UILayoutGuide? = nil) {
        child.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: guide?.leadingAnchor ?? view.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: guide?.trailingAnchor ?? view.trailingAnchor),
            child.topAnchor.constraint(equalTo: guide?.topAnchor ?? view.topAnchor),
            child.bottomAnchor.constraint(equalTo: guide?.bottomAnchor ?? view.bottomAnchor)
        ])
    }

    private func opensExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["tg", "telegram", "mailto", "tel", "sms", "whatsapp", "itms-apps"].contains(scheme)
    }

    private func recover(_ surface: WKWebView, from error: Error, navigation: WKNavigation?) {
        let failure = error as NSError
        guard failure.domain == NSURLErrorDomain, failure.code != NSURLErrorCancelled else { return }

        let failedAddress = (failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
            ?? (failure.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap(URL.init(string:))
        if failure.code == NSURLErrorUnsupportedURL,
           let failedAddress = failedAddress ?? surface.url,
           let scheme = failedAddress.scheme?.lowercased(),
           scheme != "http", scheme != "https" {
            UIApplication.shared.open(failedAddress)
            return
        }

        let transient = [NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                         NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet]
        guard surface === reader, transient.contains(failure.code), networkRetries < 2,
              let retryAddress = failedAddress ?? surface.url ?? loadedAddress else { return }
        networkRetries += 1
        let delay = networkRetries
        retryTask?.cancel()
        let isInitial = navigation != nil && navigation === initialNavigation
        retryTask = Task { [weak self, weak surface] in
            do {
                try await Task.sleep(for: .seconds(delay))
                guard let self, let surface else { return }
                let retry = surface.load(URLRequest(url: retryAddress))
                if isInitial { self.initialNavigation = retry }
            } catch is CancellationError {
                return
            } catch {
                print("Teacher Lesson Organizer: could not retry loading the resource")
            }
        }
    }

}
