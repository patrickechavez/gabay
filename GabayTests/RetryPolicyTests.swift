//
//  RetryPolicyTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct RetryPolicyTests {

    // A degenerate jitter range removes the only source of randomness, so
    // delay(afterAttempt:error:) is exact and assertable.
    private let noJitter = 1.0...1.0

    // Would fail if the attempt guard used `<=` instead of `<`; attempt == maxAttempts is exactly
    // where retrying must stop.
    @Test func shouldRetryIsFalseOnceAttemptReachesMaxAttempts() {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 3, method: .get, sentBody: false) == false)
        #expect(policy.shouldRetry(.timedOut, attempt: 2, method: .get, sentBody: false) == true)
    }

    // Would fail if isRetryable were ignored, letting a permanent failure like 404 retry just
    // because attempts remain.
    @Test(arguments: [0, 1, 2])
    func shouldRetryIsFalseForANonRetryableErrorAtAnyAttempt(attempt: Int) {
        let policy = RetryPolicy(maxAttempts: 5)

        #expect(policy.shouldRetry(.notFound(), attempt: attempt, method: .get, sentBody: false) == false)
    }

    // Would fail if the idempotent short-circuit were missing; a GET, PUT or DELETE must retry
    // regardless of sentBody.
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

    // First half of the subtle exception: a non-idempotent method whose body hasn't gone out yet is
    // safe to retry; would fail if it never retried, or only did when sentBody was wrongly true.
    @Test(arguments: [HTTPMethod.post, .patch])
    func shouldRetryIsTrueForANonIdempotentMethodWhenTheBodyWasNotSent(method: HTTPMethod) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 0, method: method, sentBody: false) == true)
    }

    // Second half: once a non-idempotent request's body is on the wire, retrying risks a duplicate
    // write; would fail if sentBody were ignored.
    @Test(arguments: [HTTPMethod.post, .patch])
    func shouldRetryIsFalseForANonIdempotentMethodWhenTheBodyWasAlreadySent(method: HTTPMethod) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.timedOut, attempt: 0, method: method, sentBody: true) == false)
    }

    // Exception to the exception: .offline means the body never actually reached the network, so
    // retrying is safe regardless of sentBody; would fail if .offline fell through to the generic
    // rule.
    @Test(arguments: [HTTPMethod.post, .patch])
    func shouldRetryIsTrueForOfflineOnANonIdempotentMethodEvenWhenTheBodyWasSent(method: HTTPMethod) {
        let policy = RetryPolicy(maxAttempts: 3)

        #expect(policy.shouldRetry(.offline, attempt: 0, method: method, sentBody: true) == true)
        #expect(policy.shouldRetry(.offline, attempt: 0, method: method, sentBody: false) == true)
    }

    // Would fail if Retry-After were ignored in favor of exponential backoff, or the header value
    // were misread.
    @Test func delayHonorsAPositiveRetryAfterFromRateLimited() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: 3))

        #expect(delay == .seconds(3))
    }

    // Would fail if a Retry-After longer than maxDelay were honored as-is instead of capped,
    // letting the server dictate an unbounded wait.
    @Test func delayCapsAPositiveRetryAfterAtMaxDelay() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: 1000))

        #expect(delay == .seconds(8))
    }

    // Would fail if a missing/non-positive Retry-After still took the rateLimited branch (e.g.
    // `retryAfter ?? 0` compared `>= 0`), producing a zero delay instead of falling back to
    // backoff.
    @Test(arguments: [nil, 0, -1] as [TimeInterval?])
    func delayFallsBackToBackoffWhenRetryAfterIsMissingOrNotPositive(retryAfter: TimeInterval?) {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: retryAfter))

        #expect(delay == .milliseconds(500))
    }

    // Would fail if the exponent used the raw attempt number instead of attempt - 1, or backoff
    // didn't grow at all.
    @Test func delayGrowsExponentiallyWithTheAttemptNumber() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(60), jitter: noJitter)

        #expect(policy.delay(afterAttempt: 1, error: .timedOut) == .milliseconds(500))
        #expect(policy.delay(afterAttempt: 2, error: .timedOut) == .seconds(1))
        #expect(policy.delay(afterAttempt: 3, error: .timedOut) == .seconds(2))
        #expect(policy.delay(afterAttempt: 4, error: .timedOut) == .seconds(4))
    }

    // Would fail if the cap applied to the Retry-After path only, not the computed backoff, letting
    // a late attempt wait far longer than maxDelay.
    @Test func delayNeverExceedsMaxDelayEvenAtALateAttempt() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(8), jitter: noJitter)

        let delay = policy.delay(afterAttempt: 10, error: .timedOut)

        #expect(delay == .seconds(8))
    }

    // Checks both bounds and distinctness: if `* Double.random(in: jitter)` were deleted, every
    // sample would collapse to the base 500ms delay, which already sits inside the 400-600ms band.
    // So only the distinct-value assertion, not the bounds alone, would catch a dropped jitter
    // multiplier.
    @Test func delayStaysWithinTheConfiguredJitterBounds() {
        let policy = RetryPolicy(baseDelay: .milliseconds(500), maxDelay: .seconds(60), jitter: 0.8...1.2)
        let lowerBound = Duration.milliseconds(400)
        let upperBound = Duration.milliseconds(600)

        var samples: Set<Duration> = []
        for _ in 0..<200 {
            let delay = policy.delay(afterAttempt: 1, error: .timedOut)
            #expect(delay >= lowerBound)
            #expect(delay <= upperBound)
            samples.insert(delay)
        }

        #expect(samples.count > 1)
    }

    // Would fail if maxAttempts <= 0 were stored as-is; shouldRetry's `attempt < maxAttempts` guard
    // would then be false for every attempt, spinning a "while attempts remain" caller forever.
    @Test(arguments: [0, -1, -100])
    func initClampsMaxAttemptsToAtLeastOne(maxAttempts: Int) {
        let policy = RetryPolicy(maxAttempts: maxAttempts)

        #expect(policy.maxAttempts == 1)
    }
}
