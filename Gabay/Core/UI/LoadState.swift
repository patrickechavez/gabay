//
//  LoadState.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

enum LoadState<Value: Sendable>: Sendable {

    case idle

    case loading

    case loaded(Value)

    case empty

    case failed(APIError)

    var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }

    var error: APIError? {
        if case let .failed(error) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isSettled: Bool {
        switch self {
        case .idle, .loading: false
        case .loaded, .empty, .failed: true
        }
    }

    var needsLoad: Bool {
        if case .idle = self { return true }
        return false
    }

    func map<T>(_ transform: (Value) -> T) -> LoadState<T> {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case let .loaded(value): .loaded(transform(value))
        case .empty: .empty
        case let .failed(error): .failed(error)
        }
    }
}

extension LoadState: Equatable where Value: Equatable {}

extension LoadState {

    static func from(_ value: Value, isEmpty: (Value) -> Bool) -> LoadState {
        isEmpty(value) ? .empty : .loaded(value)
    }
}

extension LoadState where Value: Collection {

    static func from(_ value: Value) -> LoadState {
        value.isEmpty ? .empty : .loaded(value)
    }
}

// MARK: - Loading and failing
//
// `LoadableViewModel` conformers call `perform` / `fail` instead of do/catch.

@MainActor
protocol LoadableViewModel: AnyObject {

    associatedtype Value: Sendable

    var state: LoadState<Value> { get set }
}

extension LoadableViewModel {

    /// Moves `state` through `.loading` to `.loaded`, `.empty`, or `.failed`.
    /// `isRefresh` keeps old content on screen when a reload fails.
    /// Named `perform` so it never shadows a view model's own `load()`.
    func perform(
        isRefresh: Bool = false,
        isEmpty: @escaping (Value) -> Bool = { _ in false },
        _ operation: @Sendable () async throws -> Value
    ) async {
        if !isRefresh, state.value == nil {
            state = .loading
        }

        do {
            let newValue = try await operation()
            try Task.checkCancellation()
            state = .from(newValue, isEmpty: isEmpty)
        } catch {
            fail(with: error, isRefresh: isRefresh)
        }
    }

    /// Shared failure path for loads that also update other properties.
    func fail(with error: any Error, isRefresh: Bool = false) {
        let apiError = APIError.classify(error)

        // A cancelled first load goes back to `.idle` so the view can retry.
        if case .cancelled = apiError, case .loading = state {
            state = .idle
            return
        }

        guard apiError.isUserFacing else { return }

        // Failing silently while refreshing content that's already visible.
        if isRefresh, state.value != nil { return }

        state = .failed(apiError)
    }
}

extension LoadableViewModel where Value: Collection {

    /// Same as `perform`, with empty results shown as `.empty`.
    func perform(
        isRefresh: Bool = false,
        _ operation: @Sendable () async throws -> Value
    ) async {
        await perform(isRefresh: isRefresh, isEmpty: { $0.isEmpty }, operation)
    }
}
