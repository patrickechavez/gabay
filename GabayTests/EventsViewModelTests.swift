//
//  EventsViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct EventsViewModelTests {

    private func makeViewModel(
        events: StubEventFetching = StubEventFetching(),
        auth: StubAuthenticating = StubAuthenticating()
    ) -> (EventsViewModel, Session) {
        let session = Session(auth: auth, tokenStore: StubTokenStore())
        return (EventsViewModel(events: events, session: session), session)
    }

    @Test func startsIdle() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.state == .idle)
    }

    @Test func loadPopulatesTheList() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.value?.first?.title == "Hike for Pawssion Project")
    }

    @Test func loadAlsoPopulatesMine() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        events.mineResult = .success([.fixture()])
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.mine.count == 1)
        #expect(viewModel.joined.contains("hike-for-pawssion"))
    }

    @Test func loadOnlyFetchesOnce() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.state.value?.count == 1)
    }

    @Test func joinMarksTheEventAsJoined() async {
        let events = StubEventFetching()
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.join(.fixture())

        #expect(viewModel.joined.contains("hike-for-pawssion"))
        #expect(events.joinedIds == ["hike-for-pawssion"])
    }

    @Test func aFailedLoadReportsTheFailure() async {
        let events = StubEventFetching()
        events.eventsResult = .failure(APIError.server(status: 500))
        let (viewModel, _) = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.error != nil)
    }

    @Test func anUnauthorizedLoadSignsOut() async {
        let events = StubEventFetching()
        events.eventsResult = .failure(APIError.unauthorized())
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        let (viewModel, session) = makeViewModel(events: events, auth: auth)
        try? await session.login(email: "hiker@example.test", password: "secret123")

        await viewModel.load()

        #expect(session.isSignedIn == false)
    }
}
