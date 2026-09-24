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
        events: StubEventFetching = StubEventFetching()
    ) -> EventsViewModel {
        EventsViewModel(events: events)
    }

    @Test func startsIdle() {
        let viewModel = makeViewModel()
        #expect(viewModel.state == .idle)
    }

    @Test func loadPopulatesTheList() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        let viewModel = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.value?.first?.title == "Hike for Pawssion Project")
    }

    @Test func loadAlsoPopulatesMine() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        events.mineResult = .success([.fixture()])
        let viewModel = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.mine.count == 1)
        #expect(viewModel.joined.contains("hike-for-pawssion"))
    }

    @Test func loadOnlyFetchesOnce() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        let viewModel = makeViewModel(events: events)

        await viewModel.load()
        await viewModel.load()

        #expect(events.eventsCallCount == 1)
    }

    @Test func joinMarksTheEventAsJoined() async {
        let events = StubEventFetching()
        let viewModel = makeViewModel(events: events)

        await viewModel.join(.fixture())

        #expect(viewModel.joined.contains("hike-for-pawssion"))
        #expect(events.joinedIds == ["hike-for-pawssion"])
    }

    @Test func aFailedMineFetchReportsTheFailureSeparatelyFromTheList() async {
        let events = StubEventFetching()
        events.eventsResult = .success([.fixture()])
        events.mineResult = .failure(APIError.server(status: 500))
        let viewModel = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.error == nil)
        #expect(viewModel.mineState.error != nil)
    }

    @Test func aFailedMineFetchCanBeRetried() async {
        let events = StubEventFetching()
        events.mineResult = .failure(APIError.server(status: 500))
        let viewModel = makeViewModel(events: events)

        await viewModel.load()
        #expect(viewModel.mineState.error != nil)

        events.mineResult = .success([.fixture()])
        await viewModel.refresh()

        #expect(viewModel.mine.count == 1)
        #expect(viewModel.mineState.error == nil)
    }

    @Test func aFailedLoadReportsTheFailure() async {
        let events = StubEventFetching()
        events.eventsResult = .failure(APIError.server(status: 500))
        let viewModel = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.error != nil)
    }

    // The interceptor now owns 401 handling (refresh, retry, sign out only once refresh genuinely
    // fails), so this just checks the list lands in `.failed` instead of stalling, and that a retry
    // can still succeed.
    @Test func anUnauthorizedLoadEndsInFailedAndCanBeRetried() async {
        let events = StubEventFetching()
        events.eventsResult = .failure(APIError.unauthorized())
        let viewModel = makeViewModel(events: events)

        await viewModel.load()

        #expect(viewModel.state.error != nil)

        events.eventsResult = .success([.fixture()])
        await viewModel.refresh()

        #expect(viewModel.state.value?.first?.title == "Hike for Pawssion Project")
    }
}
