//
//  PostEventViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct PostEventViewModelTests {

    private func makeValidViewModel(events: StubEventFetching = StubEventFetching()) -> PostEventViewModel {
        let viewModel = PostEventViewModel(events: events)
        viewModel.title = "Hike for Pawssion Project"
        viewModel.cause = "Pawssion Project Cebu"
        viewModel.meetingPoint = "Budlaan barangay hall"
        viewModel.meetingCoordinate = Coordinate(latitude: 10.398, longitude: 123.887)
        viewModel.feePHP = "250"
        viewModel.capacity = "25"
        viewModel.joinURLText = "https://m.me/pawssionprojectcebu"
        viewModel.eventDescription = "A hike up Budlaan to Kang-Irag."
        return viewModel
    }

    private func gpxFixture(_ xml: String = "<gpx><trk><trkseg><trkpt lat=\"9.8\" lon=\"123.3\"/><trkpt lat=\"9.9\" lon=\"123.3\"/></trkseg></trk></gpx>") -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gpx")
        try! Data(xml.utf8).write(to: url)
        return url
    }

    @Test func cannotSubmitAnEmptyForm() {
        let viewModel = PostEventViewModel(events: StubEventFetching())
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitOnceEveryFieldIsFilledCorrectly() {
        #expect(makeValidViewModel().canSubmit == true)
    }

    @Test func cannotSubmitWithoutAMeetingCoordinate() {
        let viewModel = makeValidViewModel()
        viewModel.meetingCoordinate = nil
        #expect(viewModel.canSubmit == false)
    }

    @Test func rejectsANonNumericFee() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "free"
        #expect(viewModel.canSubmit == false)
    }

    @Test func rejectsAZeroCapacity() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "0"
        #expect(viewModel.canSubmit == false)
    }

    @Test func rejectsAJoinLinkWithNoScheme() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "m.me/pawssionprojectcebu"
        #expect(viewModel.canSubmit == false)
    }

    @Test func aBlankPhotoLinkIsFine() {
        #expect(makeValidViewModel().canSubmit == true)
    }

    @Test func rejectsAPhotoLinkWithNoScheme() {
        let viewModel = makeValidViewModel()
        viewModel.photoURLText = "example.test/photo.jpg"
        #expect(viewModel.canSubmit == false)
    }

    @Test func pickingAValidGPXComputesRouteStats() throws {
        let viewModel = makeValidViewModel()
        let file = gpxFixture()
        defer { try? FileManager.default.removeItem(at: file) }

        viewModel.pickGPX(at: file)

        #expect(viewModel.route != nil)
        #expect(viewModel.gpxError == nil)
    }

    @Test func aGPXIsOptionalAndDoesNotBlockSubmission() {
        // No GPX picked at all, canSubmit is still true from the other fields.
        #expect(makeValidViewModel().canSubmit == true)
    }

    @Test func pickingAnUnreadableGPXReportsAnErrorAndClearsAnyRoute() throws {
        let viewModel = makeValidViewModel()
        let badFile = gpxFixture("not gpx at all")
        defer { try? FileManager.default.removeItem(at: badFile) }

        viewModel.pickGPX(at: badFile)

        #expect(viewModel.route == nil)
        #expect(viewModel.gpxError != nil)
    }

    @Test func removeGPXClearsTheRoute() throws {
        let viewModel = makeValidViewModel()
        let file = gpxFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        viewModel.pickGPX(at: file)

        viewModel.removeGPX()

        #expect(viewModel.route == nil)
    }

    @Test func submitCreatesTheEventAndMarksItSubmitted() async {
        let events = StubEventFetching()
        events.createResult = .success(.fixture(status: .pending))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.didSubmit == true)
    }

    @Test func submitWithAPickedGPXAlsoUploadsIt() async throws {
        let events = StubEventFetching()
        events.createResult = .success(.fixture(status: .pending))
        events.uploadGPXResult = .success(.fixture(status: .pending, gpxURL: URL(string: "https://example.test/r.gpx")))
        let viewModel = makeValidViewModel(events: events)
        let file = gpxFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        viewModel.pickGPX(at: file)

        await viewModel.submit()

        #expect(viewModel.didSubmit == true)
        #expect(events.uploadedGPXEventIds == ["hike-for-pawssion"])
    }

    @Test func aFailedSubmitReportsTheFailureAndDoesNotMarkSubmitted() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.validationFailed)
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.didSubmit == false)
        #expect(viewModel.failure != nil)
    }
}
