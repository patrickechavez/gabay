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
        viewModel.date = Date(timeIntervalSince1970: 1_800_000_000)
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
        events.uploadGPXResult = .success(.fixture(gpxURL: URL(string: "https://example.test/r.gpx"), status: .pending))
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
        events.createResult = .failure(APIError.validation(ValidationErrors(fields: [:], summary: nil)))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.didSubmit == false)
        #expect(viewModel.action.error != nil)
    }

    @Test func aSuccessfulSubmitShowsAConfirmationAlert() async {
        let events = StubEventFetching()
        events.createResult = .success(.fixture(status: .pending))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.alert != nil)
    }

    @Test func aFailedSubmitDoesNotShowAConfirmationAlert() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.validation(ValidationErrors(fields: [:], summary: nil)))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.alert == nil)
    }

    @Test func cannotSubmitWithoutADate() {
        let viewModel = makeValidViewModel()
        viewModel.date = nil
        #expect(viewModel.canSubmit == false)
    }

    @Test func anUntouchedFeeShowsNoError() {
        #expect(PostEventViewModel(events: StubEventFetching()).feeError == nil)
    }

    @Test func aNonNumericFeeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "two hundred"
        #expect(viewModel.feeError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aNumericFeeShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "250"
        #expect(viewModel.feeError == nil)
    }

    @Test func aFreeHikeIsAllowed() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "0"
        #expect(viewModel.feeError == nil)
        #expect(viewModel.canSubmit)
    }

    @Test func aNegativeFeeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "-100"
        #expect(viewModel.feeError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aCapacityOfZeroShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "0"
        #expect(viewModel.capacityError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aNegativeCapacityShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "-5"
        #expect(viewModel.capacityError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aDecimalCapacityShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "3.5"
        #expect(viewModel.capacityError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aNonNumericCapacityShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "abc"
        #expect(viewModel.capacityError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aPositiveCapacityShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "25"
        #expect(viewModel.capacityError == nil)
    }

    @Test func aJoinLinkWithNoSchemeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "m.me/pawssionprojectcebu"
        #expect(viewModel.joinURLError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aFullJoinLinkShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "https://m.me/pawssionprojectcebu"
        #expect(viewModel.joinURLError == nil)
    }

    @Test func aJoinLinkWithNoHostShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "https://"
        #expect(viewModel.joinURLError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aNonWebSchemeJoinLinkShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "mailto:organizer@example.com"
        #expect(viewModel.joinURLError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func anEmptyPhotoLinkShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.photoURLText = ""
        #expect(viewModel.photoURLError == nil)
        #expect(viewModel.canSubmit)
    }

    @Test func aPhotoLinkWithNoSchemeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.photoURLText = "example.com/hike.jpg"
        #expect(viewModel.photoURLError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aServerFieldMessageWinsOverTheLocalRule() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.validation(ValidationErrors(
            fields: ["feePHP": ["Fee must not exceed 5000."]],
            summary: nil
        )))
        let viewModel = makeValidViewModel(events: events)
        // A perfectly valid fee, so the local rule alone would say nothing.
        viewModel.feePHP = "9999"

        await viewModel.submit()

        #expect(viewModel.feeError == "Fee must not exceed 5000.")
    }

    @Test func aValidationErrorOnAFieldWithNoSlotShowsTheWholeFormMessage() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.validation(ValidationErrors(
            fields: ["title": ["That title is already taken."]],
            summary: nil
        )))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.submitErrorMessage != nil)
    }

    @Test func aValidationErrorOnlyOnFieldsWithSlotsSuppressesTheWholeFormMessage() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.validation(ValidationErrors(
            fields: ["feePHP": ["Fee must not exceed 5000."], "capacity": ["Too many hikers."]],
            summary: nil
        )))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()

        #expect(viewModel.submitErrorMessage == nil)
    }

    @Test func editingAFieldAfterAFailedSubmitClearsTheStaleMessage() async {
        let events = StubEventFetching()
        events.createResult = .failure(APIError.server(status: 500))
        let viewModel = makeValidViewModel(events: events)

        await viewModel.submit()
        #expect(viewModel.submitErrorMessage != nil)

        // canSubmit goes false, so nothing will ever resubmit to clear it
        // the old way; the edit itself has to be what clears it.
        viewModel.capacity = "0"

        #expect(viewModel.canSubmit == false)
        #expect(viewModel.submitErrorMessage == nil)
    }
}
