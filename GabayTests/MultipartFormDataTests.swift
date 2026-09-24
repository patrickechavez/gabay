//
//  MultipartFormDataTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct MultipartFormDataTests {

    // Fails if any field, the file's name, or the boundary delimiter is dropped or wrong.
    @Test func encodedBodyContainsTheBoundaryEveryFieldAndTheFile() throws {
        var form = MultipartFormData(boundary: "TestBoundary")
        form.addField("distanceM", value: "4761")
        form.addFile("gpx", filename: "hike.gpx", mimeType: "application/gpx+xml", data: Data("<gpx></gpx>".utf8))

        let text = try #require(String(data: form.encoded(), encoding: .utf8))

        #expect(text.contains("--TestBoundary\r\n"))
        #expect(text.contains("Content-Disposition: form-data; name=\"distanceM\"\r\n\r\n4761\r\n"))
        #expect(text.contains("Content-Disposition: form-data; name=\"gpx\"; filename=\"hike.gpx\"\r\n"))
        #expect(text.contains("Content-Type: application/gpx+xml\r\n\r\n<gpx></gpx>\r\n"))
    }

    // Isolated so a broken closing delimiter fails on its own, not masked by a `contains` check
    // elsewhere.
    @Test func encodedBodyEndsWithTheClosingBoundaryDelimiter() {
        var form = MultipartFormData(boundary: "TestBoundary")
        form.addField("distanceM", value: "4761")

        let text = String(decoding: form.encoded(), as: UTF8.self)

        #expect(text.hasSuffix("--TestBoundary--\r\n"))
    }

    // Fails if the encoder round-trips the payload through a text encoding and corrupts non-ASCII
    // bytes.
    @Test func fileBytesSurviveEncodingUnmodified() {
        var form = MultipartFormData(boundary: "TestBoundary")
        let fileBytes = Data([0x00, 0xFF, 0x10, 0x7F, 0x80])
        form.addFile("gpx", filename: "route.gpx", mimeType: "application/gpx+xml", data: fileBytes)

        let encoded = form.encoded()

        #expect(encoded.range(of: fileBytes) != nil)
    }

    // Fails if `contentType` and `encoded()` disagree on the boundary, producing a body the server
    // can't parse.
    @Test func contentTypeAdvertisesTheSameBoundaryTheBodyUses() {
        let form = MultipartFormData(boundary: "TestBoundary")

        #expect(form.contentType == "multipart/form-data; boundary=TestBoundary")
    }
}
