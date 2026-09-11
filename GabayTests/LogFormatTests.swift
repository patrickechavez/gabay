//
//  LogFormatTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct LogFormatTests {

    private func json(_ text: String) -> Data { Data(text.utf8) }

    // MARK: - headers

    @Test func reportsNoHeaders() {
        #expect(LogFormat.headers([:]) == "none")
    }

    @Test func showsAuthorizationInFull() {
        let line = LogFormat.headers(["Authorization": "Bearer eyJhbGci"])

        #expect(line == "    Authorization: Bearer eyJhbGci")
    }

    @Test func redactsCookies() {
        let line = LogFormat.headers(["Set-Cookie": "session=abc"])

        #expect(line == "    Set-Cookie: <redacted>")
    }

    // MARK: - body

    @Test func reportsEmptyBody() {
        #expect(LogFormat.body(Data()) == "<empty>")
    }

    @Test func redactsSensitiveBodyKeys() {
        let line = LogFormat.body(json(#"{"email":"raven@example.com","password":"hunter2"}"#))

        #expect(line == #"{"email":"raven@example.com","password":"<redacted>"}"#)
    }

    @Test func redactsNestedSensitiveKeys() {
        let line = LogFormat.body(json(#"{"session":{"refresh_token":"abc"}}"#))

        #expect(line == #"{"session":{"refresh_token":"<redacted>"}}"#)
    }

    @Test func sortsKeysSoOfflineAndSentBodiesLineUp() {
        let line = LogFormat.body(json(#"{"qty":3,"name":"Bolt","id":"9f2c"}"#))

        #expect(line == #"{"id":"9f2c","name":"Bolt","qty":3}"#)
    }

    @Test func summarizesBodiesTooLargeToLog() {
        let large = json(#"{"note":""# + String(repeating: "x", count: 5_000) + #""}"#)

        #expect(LogFormat.body(large) == "<\(large.count) bytes — too large to log>")
    }

    @Test func summarizesMultipartBodies() {
        let line = LogFormat.body(json("--boundary"), contentType: "multipart/form-data; boundary=x")

        #expect(line == "<multipart, 10 bytes>")
    }

    @Test func encodesModelsTheWayTheAPIClientWould() {
        struct Draft: Encodable {
            let name = "Bolt"
            let password = "hunter2"
        }

        #expect(LogFormat.body(encoding: Draft()) == #"{"name":"Bolt","password":"<redacted>"}"#)
    }
}
