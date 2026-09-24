//
//  APIErrorTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// classify(_:) isn't covered here: it's @MainActor and reaches into Breadcrumb/Observability, so it belongs with a test that can install a spy crash reporter.
struct APIErrorTests {

    @Test(arguments: [
        (401, APIError.unauthorized()),
        (403, APIError.forbidden()),
        (404, APIError.notFound()),
        (409, APIError.conflict()),
        (426, APIError.updateRequired()),
        (503, APIError.maintenance()),
    ])
    func mapsAKnownStatusCodeToItsCase(status: Int, expected: APIError) {
        let error = APIError.from(statusCode: status, data: Data(), headers: [:])

        #expect(error == expected)
    }

    @Test func mapsAnUnlistedStatusCodeToServer() {
        let error = APIError.from(statusCode: 418, data: Data(), headers: [:])

        #expect(error == .server(status: 418))
    }

    @Test func maps422ToValidationCarryingTheFieldErrors() {
        let body = Data("""
        {"message": "Validation failed", "errors": {"email": ["is invalid"]}}
        """.utf8)

        let error = APIError.from(statusCode: 422, data: body, headers: [:])

        #expect(error == .validation(ValidationErrors(
            fields: ["email": ["is invalid"]],
            summary: "Validation failed"
        )))
    }

    @Test func maps400ToValidationWhenTheBodyCarriesFieldErrors() {
        let body = Data("""
        {"errors": {"email": ["is invalid"], "password": ["too short"]}}
        """.utf8)

        let error = APIError.from(statusCode: 400, data: body, headers: [:])

        #expect(error == .validation(ValidationErrors(
            fields: ["email": ["is invalid"], "password": ["too short"]],
            summary: nil
        )))
    }

    @Test func maps400ToServerWhenTheBodyCarriesNoFieldErrors() {
        let body = Data("""
        {"message": "Bad request"}
        """.utf8)

        let error = APIError.from(statusCode: 400, data: body, headers: [:])

        #expect(error == .server(status: 400, message: "Bad request"))
    }

    @Test func reads429RetryAfterFromTheHeaders() {
        let error = APIError.from(statusCode: 429, data: Data(), headers: ["Retry-After": "30"])

        #expect(error == .rateLimited(retryAfter: 30))
    }

    @Test func toleratesAMissingRetryAfterHeader() {
        let error = APIError.from(statusCode: 429, data: Data(), headers: [:])

        #expect(error == .rateLimited(retryAfter: nil))
    }

    @Test func toleratesAnUnparseableRetryAfterHeader() {
        let error = APIError.from(statusCode: 429, data: Data(), headers: ["Retry-After": "soon"])

        #expect(error == .rateLimited(retryAfter: nil))
    }

    @Test func mapsNotConnectedToOffline() {
        let error = APIError.from(transportError: URLError(.notConnectedToInternet))

        #expect(error == .offline)
    }

    @Test func mapsTimedOutToTimedOut() {
        let error = APIError.from(transportError: URLError(.timedOut))

        #expect(error == .timedOut)
    }

    @Test func mapsURLErrorCancelledToCancelled() {
        let error = APIError.from(transportError: URLError(.cancelled))

        #expect(error == .cancelled)
    }

    @Test func mapsACertificateErrorToServerTrustFailed() {
        let error = APIError.from(transportError: URLError(.serverCertificateUntrusted))

        #expect(error == .serverTrustFailed)
    }

    @Test func mapsSwiftCancellationErrorToCancelled() {
        let error = APIError.from(transportError: CancellationError())

        #expect(error == .cancelled)
    }

    @Test(arguments: [
        APIError.offline,
        .timedOut,
        .transport(detail: "connection reset"),
        .rateLimited(),
        .server(status: 503),
    ])
    func isRetryableForTransientFailures(error: APIError) {
        #expect(error.isRetryable)
    }

    @Test(arguments: [
        APIError.unauthorized(),
        .validation(ValidationErrors(fields: [:], summary: nil)),
        .server(status: 404),
    ])
    func isNotRetryableForFailuresThatWontChangeOnTheirOwn(error: APIError) {
        #expect(!error.isRetryable)
    }

    @Test func validationErrorsReturnsThePayloadForValidation() {
        let errors = ValidationErrors(fields: ["email": ["is invalid"]], summary: "Bad input")

        #expect(APIError.validation(errors).validationErrors == errors)
    }

    @Test func validationErrorsIsNilForOtherCases() {
        #expect(APIError.unauthorized().validationErrors == nil)
    }
}
