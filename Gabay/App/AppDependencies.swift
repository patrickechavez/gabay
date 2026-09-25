//
//  AppDependencies.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@MainActor
final class AppDependencies {

    let analytics: any AnalyticsTracking
    let crashes: any CrashReporting

    let session: Session
    let eventsViewModel: EventsViewModel
    let networkMonitor: NetworkMonitor
    let navigator: AppNavigator

    // Only the publishing repository is held: the browsing one is handed straight to
    // `eventsViewModel` at construction and nothing else asks for it.
    private let publishing: any EventPublishingRepository

    init(
        session: Session,
        publishing: any EventPublishingRepository,
        eventsViewModel: EventsViewModel,
        networkMonitor: NetworkMonitor,
        navigator: AppNavigator,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.session = session
        self.publishing = publishing
        self.eventsViewModel = eventsViewModel
        self.networkMonitor = networkMonitor
        self.navigator = navigator
        self.analytics = analytics
        self.crashes = crashes
    }

    static func live() -> AppDependencies {
        // Real reporting when Firebase is both linked and configured, no-ops otherwise. The seams
        // are the same either way.
        let reporting = FirebaseBootstrap.start()
        let analytics = reporting?.analytics ?? NoopAnalyticsTracker()
        let crashes = reporting?.crashes ?? NoopCrashReporter()

        Observability.install(analytics: analytics, crashes: crashes)

        let tokenStore = KeychainTokenStore()
        let sessionLink = SessionLink()

        // Both clients share this pinner: an unpinned refresh client would leak the refresh token,
        // which is worth as much as the access token to a man in the middle.
        let pinner = CertificatePinner(pinnedHashes: APIConfig.pinnedPublicKeyHashes)
        let pinnedSession = URLSession(configuration: .default, delegate: pinner, delegateQueue: nil)

        // Bare client with no interceptors, used only by the refresher: sharing the intercepted
        // client below would make a failing refresh recurse into the interceptor that triggered it.
        let refreshClient = URLSessionAPIClient(baseURL: APIConfig.baseURL, session: pinnedSession)
        let coordinator = TokenRefreshCoordinator(
            store: tokenStore,
            refresher: LiveTokenRefresher(api: refreshClient),
            link: sessionLink
        )

        // LoggingInterceptor must come after AuthInterceptor: interceptors run in array order, so
        // this logs the request as actually sent, with Authorization attached (redacted by
        // LogFormat before it reaches the console).
        var interceptors: [any RequestInterceptor] = [AuthInterceptor(coordinator: coordinator)]
        if APIConfig.isLoggingEnabled {
            interceptors.append(LoggingInterceptor())
        }
        let api = URLSessionAPIClient(
            baseURL: APIConfig.baseURL,
            session: pinnedSession,
            interceptors: interceptors
        )
        let session = Session(auth: LiveAuthRepository(api: api), tokenStore: tokenStore)
        sessionLink.session = session
        let events = LiveEventRepository(api: api)

        return AppDependencies(
            session: session,
            publishing: events,
            eventsViewModel: EventsViewModel(events: events),
            networkMonitor: NetworkMonitor(),
            navigator: AppNavigator(),
            analytics: analytics,
            crashes: crashes
        )
    }

    func makeSignInViewModel() -> SignInViewModel {
        SignInViewModel(session: session)
    }

    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel(session: session)
    }

    func makePostEventViewModel() -> PostEventViewModel {
        PostEventViewModel(events: publishing)
    }
}
