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

    private let events: any EventFetching

    init(
        session: Session,
        events: any EventFetching,
        eventsViewModel: EventsViewModel,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.session = session
        self.events = events
        self.eventsViewModel = eventsViewModel
        self.analytics = analytics
        self.crashes = crashes
    }

    static func live() -> AppDependencies {
        // Nothing is reported anywhere, but the seams stay.
        let analytics = NoopAnalyticsTracker()
        let crashes = NoopCrashReporter()

        Observability.install(analytics: analytics, crashes: crashes)

        let tokenStore = KeychainTokenStore()
        let sessionLink = SessionLink()

        // Both clients below talk to the same host, so both go through the
        // same pinner. A refresh client left off pinning would be a hole:
        // it carries the refresh token, which is worth just as much as the
        // access token to whoever is sitting in the middle.
        let pinner = CertificatePinner(pinnedHashes: APIConfig.pinnedPublicKeyHashes)
        let pinnedSession = URLSession(configuration: .default, delegate: pinner, delegateQueue: nil)

        // A bare client with no interceptors, used only by the refresher: if
        // it shared the intercepted client below, a failing refresh would
        // recurse into the interceptor that triggered it.
        let refreshClient = URLSessionAPIClient(baseURL: APIConfig.baseURL, session: pinnedSession)
        let coordinator = TokenRefreshCoordinator(
            store: tokenStore,
            refresher: LiveTokenRefresher(api: refreshClient),
            link: sessionLink
        )

        // LoggingInterceptor must come after AuthInterceptor: interceptors
        // run in array order, so this logs the request as actually sent,
        // with the Authorization header already attached (and redacted by
        // LogFormat before anything reaches the console).
        var interceptors: [any RequestInterceptor] = [AuthInterceptor(coordinator: coordinator)]
        if APIConfig.isLoggingEnabled {
            interceptors.append(LoggingInterceptor())
        }
        let api = URLSessionAPIClient(
            baseURL: APIConfig.baseURL,
            session: pinnedSession,
            interceptors: interceptors
        )
        let session = Session(auth: AuthClient(api: api), tokenStore: tokenStore)
        sessionLink.session = session
        let events = EventClient(api: api)

        return AppDependencies(
            session: session,
            events: events,
            eventsViewModel: EventsViewModel(events: events),
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
        PostEventViewModel(events: events)
    }
}
