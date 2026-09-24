//
//  MultipartFormDataTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct MultipartFormDataTests {

    // Would fail if a field were dropped, misnamed, or its value mangled,
    // if the file part's name or filename were wrong, or if the boundary
    // delimiter between parts were missing - each assertion pins one piece
    // the encoder must reproduce verbatim.
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

    // Isolated from the field/file assertions above so a broken closing
    // delimiter (missing trailing `--`, wrong boundary, or a body that
    // simply never closes) fails on its own rather than being masked by a
    // `contains` check elsewhere in the string.
    @Test func encodedBodyEndsWithTheClosingBoundaryDelimiter() {
        var form = MultipartFormData(boundary: "TestBoundary")
        form.addField("distanceM", value: "4761")

        let text = String(decoding: form.encoded(), as: UTF8.self)

        #expect(text.hasSuffix("--TestBoundary--\r\n"))
    }

    // File bytes must ride through unmodified. Would fail if the encoder
    // round-tripped the payload through a text encoding and lost or
    // corrupted the non-ASCII bytes.
    @Test func fileBytesSurviveEncodingUnmodified() {
        var form = MultipartFormData(boundary: "TestBoundary")
        let fileBytes = Data([0x00, 0xFF, 0x10, 0x7F, 0x80])
        form.addFile("gpx", filename: "route.gpx", mimeType: "application/gpx+xml", data: fileBytes)

        let encoded = form.encoded()

        #expect(encoded.range(of: fileBytes) != nil)
    }

    // Would fail if `contentType` and `encoded()` ever disagreed on the
    // boundary string, which would produce a body the server can't parse
    // even though each half looks correct in isolation.
    @Test func contentTypeAdvertisesTheSameBoundaryTheBodyUses() {
        let form = MultipartFormData(boundary: "TestBoundary")

        #expect(form.contentType == "multipart/form-data; boundary=TestBoundary")
    }
}
