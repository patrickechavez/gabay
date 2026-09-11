//
//  HomeViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class HomeViewModel: LoadableViewModel {

    var state: LoadState<[Item]> = .idle

    var searchText = ""

    private(set) var isLoadingMore = false

    @ObservationIgnored private var nextPage: PageRequest?

    @ObservationIgnored private let repository: any ItemRepository

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    var hasMorePages: Bool { nextPage != nil }

    var isSearching: Bool { !searchText.trimmed.isEmpty }

    func load(isRefresh: Bool = false) async {
        let term = searchText.trimmed
        let request = PageRequest.first

        if !isRefresh, state.value == nil {
            state = .loading
        }

        do {
            let page = term.isEmpty
                ? try await repository.items(request)
                : try await repository.search(term, page: request)

            try Task.checkCancellation()
            nextPage = request.next(after: page)
            state = .from(page.items)
        } catch {
            fail(with: error, isRefresh: isRefresh)
        }
    }

    func loadMore() async {
        guard let request = nextPage, !isLoadingMore, let current = state.value else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let term = searchText.trimmed
        do {
            let page = term.isEmpty
                ? try await repository.items(request)
                : try await repository.search(term, page: request)

            try Task.checkCancellation()

            var seen = Set(current.map(\.id))
            let fresh = page.items.filter { seen.insert($0.id).inserted }

            state = .loaded(current + fresh)
            nextPage = request.next(after: page)
        } catch {
            let apiError = APIError.classify(error)
            guard apiError.isUserFacing else { return }
            AppLogger.data.error("Pagination failed: \(apiError.localizedDescription, privacy: .public)")
            nextPage = nil
        }
    }

    func shouldLoadMore(after item: Item) -> Bool {
        guard let items = state.value, hasMorePages, !isLoadingMore else { return false }
        guard let index = items.firstIndex(of: item) else { return false }
        return index >= items.count - 3
    }
}
