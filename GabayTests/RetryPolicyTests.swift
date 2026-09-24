//
//  RetryPolicyTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct RetryPolicyTests {

    // A degenerate jitter range removes the only source of randomness so
    // delay(afterAttempt:error:) produces an exact, assertable Duration.
    private let noJitter = 1.0...1.0

    // Would fail if the attempt guard were dropped or used `<=` instead of
    // `<`, since attempt == maxAttempts is exactly the boundary where
    // retrying must stop.
    @Test func shouldRetryIsFalseOnceAttemptReachesMaxAttempts() {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 3, method: .get, sentBody: false) == false)
        #expect(policy.shouldRetry(.timedOut, attempt: 2, method: .get, sentBody: false) == true)
    }

    // Would fail if isRetryable were ignored, letting a permanent failure
    // like 404 retry just because attempts remain.
    @Test(arguments: [0, 1, 2])
    func shouldRetryIsFalseForANonRetryableErrorAtAnyAttempt(attempt: Int) {
        let policy = RetryPolicy(maxAttempts: 5)

        #expect(policy.shouldRetry(.notFound(), attempt: attempt, method: .get, sentBody: false) == false)
    }

    // Would fail if the idempotent short-circuit were missing, since a GET,
    // PUT or DELETE must retry whether or not a body was already sent.
    @Test(arguments: [
        (HTTPMethod.get, false),
        (.get, true),
        (.put, false),
        (.put, true),
        (.delete, false),
        (.delete, true),
    ])
    func shouldRetryIsTrueForAnIdempotentMethodRegardlessOfSentBody(method: HTTPMethod, sentBody: Bool) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 0, method: method, sentBody: sentBody) == true)
    }

    // The first half of the subtle exception: a non-idempotent method whose
    // body has not gone out yet is safe to retry. Would fail if the method
    // branch retried non-idempotent requests never, or only when sentBody
    // were (wrongly) true.
    @Test(arguments: [HTTPMethod.post, .patch])
    func shouldRetryIsTrueForANonIdempotentMethodWhenTheBodyWasNotSent(method: HTTPMethod) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 0, method: method, sentBody: false) == true)
    }

    // The second half: once a non-idempotent request's body is already on
    // the wire, retrying risks a duplicate write, so it must refuse. Would
    // fail if sentBody were ignored for non-idempotent methods.
    @Test(arguments: [HTTPMethod.post, .patch])
    func shouldRetryIsFalseForANonIdempotentMethodWhenTheBodyWasAlreadySent(method: HTTPMethod) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 0, method: method, sentBody: true) == false)
    }

    // The exception to the exception: .offline means the request never
    // actually reached the network, so even a "sent" body was not really
    // sent, and retrying is safe regardless of sentBody. Would fail if
    // .offline fell through to the generic !sentBody rule instead of its
    // own `case .offline: return true`.
    @Test(arguments: [HTTPMethod.post, .patch])
    func shouldRetryIsTrueForOfflineOnANonIdempotentMethodEvenWhenTheBodyWasSent(method: HTTPMethod) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.offline, attempt: 0, method: method, sentBody: true) == true)
        #expect(policy.shouldRetry(.offline, attempt: 0, method: method, sentBody: false) == true)
    }

    // Would fail if Retry-After were ignored in favor of the exponential
    // backoff, or if the header value were misread.
    @Test func delayHonorsAPositiveRetryAfterFromRateLimited() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: 3))

        #expect(delay == .seconds(3))
    }

    // Would fail if a Retry-After longer than maxDelay were honored as-is
    // instead of being capped, letting the server dictate an unbounded wait.
    @Test func delayCapsAPositiveRetryAfterAtMaxDelay() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: 1000))

        #expect(delay == .seconds(8))
    }

    // Would fail if a missing or non-positive Retry-After still took the
    // rateLimited branch (e.g. by using `retryAfter ?? 0` and comparing
    // `>= 0`), which would produce a zero-second delay instead of falling
    // back to the exponential backoff.
    @Test(arguments: [nil, 0, -1] as [TimeInterval?])
    func delayFallsBackToBackoffWhenRetryAfterIsMissingOrNotPositive(retryAfter: TimeInterval?) {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: retryAfter))

        #expect(delay == .milliseconds(500))
    }

    // Would fail if the exponent were computed from the raw attempt number
    // instead of attempt - 1, or if backoff did not grow at all.
    @Test func delayGrowsExponentiallyWithTheAttemptNumber() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(60), jitter: noJitter)

        #expect(policy.delay(afterAttempt: 1, error: .timedOut) == .milliseconds(500))
        #expect(policy.delay(afterAttempt: 2, error: .timedOut) == .seconds(1))
        #expect(policy.delay(afterAttempt: 3, error: .timedOut) == .seconds(2))
        #expect(policy.delay(afterAttempt: 4, error: .timedOut) == .seconds(4))
    }

    // Would fail if the cap were applied to the Retry-After path only and
    // not to the computed backoff, letting a late attempt wait far longer
    // than maxDelay.
    @Test func delayNeverExceedsMaxDelayEvenAtALateAttempt() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 10, error: .timedOut)

        #expect(delay == .seconds(8))
    }

    // Would fail if jitter were not applied at all (every sample would
    // equal the base delay) or if it could push the result outside the
    // configured range in either direction. Asserts bounds, not an exact
    // value, since the multiplier is random.
    @Test func delayStaysWithinTheConfiguredJitterBounds() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(60), jitter: 0.8...1.2)
        let lowerBound = Duration.milliseconds(400)
        let upperBound = Duration.milliseconds(600)

        for _ in 0..<200 {
            let delay = policy.delay(afterAttempt: 1, error: .timedOut)
            #expect(delay >= lowerBound)
            #expect(delay <= upperBound)
        }
    }

    // Would fail if maxAttempts: 0 (or a negative value) were stored as-is,
    // which would make shouldRetry's `attempt < maxAttempts` guard false
    // for every attempt including 0, or a caller that loops "while attempts
    // remain" spin forever on a value that never increases.
    @Test(arguments: [0, -1, -100])
    func initClampsMaxAttemptsToAtLeastOne(maxAttempts: Int) {
        let policy = RetryPolicy(maxAttempts: maxAttempts)

        #expect(policy.maxAttempts == 1)
    }
}
