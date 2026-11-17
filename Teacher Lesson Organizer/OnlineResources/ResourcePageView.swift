import SwiftUI
@preconcurrency import WebKit

struct ResourcePageView: UIViewControllerRepresentable {
    @Binding var address: URL?

    func makeUIViewController(context: Context) -> ResourcePageController {
        ResourcePageController()
    }

    func updateUIViewController(_ controller: ResourcePageController, context: Context) {
        if let address {
            controller.display(address)
        }
    }
}

final class ResourcePageController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private lazy var reader: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return makePage(configuration)
    }()
    private var tabs: [ResourceTab] = []
    private var loading: UIHostingController<LaunchScreen>?
    private var loadedAddress: URL?
    private var retryTask: Task<Void, Never>?
    private var networkRetries = 0
    private var processRestarts = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        mount(reader, guide: view.safeAreaLayoutGuide)
        mountLaunchScreen()
    }

    private func mountLaunchScreen() {
        let screen = UIHostingController(rootView: LaunchScreen())
        addChild(screen)
        mount(screen.view)
        screen.didMove(toParent: self)
        loading = screen
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
        reader.load(URLRequest(url: destination))
    }

    func webView(_ surface: WKWebView, didFinish navigation: WKNavigation!) {
        guard surface === reader else { return }
        retryTask?.cancel()
        dismissLoading()
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
        let tab = ResourceTab(page: page)
        tab.onClose = { [weak self, weak page] in
            if let page { self?.closeTab(for: page) }
        }
        dismissLoading()
        mount(tab, guide: view.safeAreaLayoutGuide)
        tabs.append(tab)
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
        guard let index = tabs.firstIndex(where: { $0.page === surface }) else { return }
        let tab = tabs.remove(at: index)
        tab.removeFromSuperview()
        surface.stopLoading()
    }

    func webViewWebContentProcessDidTerminate(_ surface: WKWebView) {
        guard processRestarts < 2 else { return }
        processRestarts += 1
        if let url = surface.url ?? (surface === reader ? loadedAddress : nil) {
            surface.load(URLRequest(url: url))
        }
    }

    func webView(_ surface: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recover(surface, from: error)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recover(surface, from: error)
    }

    private func makePage(_ configuration: WKWebViewConfiguration) -> WKWebView {
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

    private func recover(_ surface: WKWebView, from error: Error) {
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
        retryTask = Task { [weak surface] in
            do {
                try await Task.sleep(for: .seconds(delay))
                surface?.load(URLRequest(url: retryAddress))
            } catch is CancellationError {
                return
            } catch {
                print("Teacher Lesson Organizer: could not retry loading the resource")
            }
        }
    }

    private func dismissLoading() {
        guard let loading else { return }
        loading.willMove(toParent: nil)
        loading.view.removeFromSuperview()
        loading.removeFromParent()
        self.loading = nil
    }
}


private final class ResourceTab: UIView {
    let page: WKWebView
    var onClose: (() -> Void)?

    init(page: WKWebView) {
        self.page = page
        super.init(frame: .zero)
        backgroundColor = .systemBackground

        let close = UIButton(type: .close)
        close.accessibilityLabel = "Close tab"
        close.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        let toolbar = UIView()
        toolbar.backgroundColor = .secondarySystemBackground
        addSubview(toolbar)
        toolbar.addSubview(close)
        addSubview(page)

        for child in [toolbar, close, page] {
            child.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            close.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            close.trailingAnchor.constraint(equalTo: toolbar.layoutMarginsGuide.trailingAnchor),
            page.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            page.leadingAnchor.constraint(equalTo: leadingAnchor),
            page.trailingAnchor.constraint(equalTo: trailingAnchor),
            page.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
