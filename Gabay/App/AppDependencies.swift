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

        // A bare client with no interceptors, used only by the refresher: if
        // it shared the intercepted client below, a failing refresh would
        // recurse into the interceptor that triggered it.
        let refreshClient = URLSessionAPIClient(baseURL: APIConfig.baseURL)
        let coordinator = TokenRefreshCoordinator(
            store: tokenStore,
            refresher: LiveTokenRefresher(api: refreshClient),
            link: sessionLink
        )

        let api = URLSessionAPIClient(
            baseURL: APIConfig.baseURL,
            interceptors: [AuthInterceptor(coordinator: coordinator)]
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
