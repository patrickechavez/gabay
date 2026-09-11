//
//  ItemDetailView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct ItemDetailView: View {

    @State private var viewModel: ItemDetailViewModel

    @Environment(Router<HomeRoute>.self) private var router

    init(viewModel: ItemDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("Loading", comment: "Accessibility label for a loading spinner"))

            case let .loaded(item):
                detail(item)

            case .empty:
                ContentUnavailableView {
                    Label("Item unavailable", systemImage: "questionmark.folder")
                }

            case let .failed(error):
                ErrorStateView(error: error, retry: { await viewModel.load() })
            }
        }
        .navigationTitle(viewModel.state.value?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {

            guard viewModel.state.needsLoad else { return }
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load(isRefresh: true)
        }
    }

    private func detail(_ item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                CachedAsyncImage(url: item.thumbnailURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    SkeletonView(cornerRadius: Theme.Radius.lg)
                        .aspectRatio(4 / 3, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(item.title)
                        .font(Theme.Font.sectionTitle)

                    Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(Theme.Font.cardTitle)
                        .foregroundStyle(Theme.Color.accent)
                }

                Text(item.description)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.secondaryText)

                Button {
                    router.push(.itemReviews(id: item.id))
                } label: {
                    Text("Reviews", comment: "Button that opens the item reviews screen")
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            ItemDetailView(viewModel: dependencies.makeItemDetailViewModel(id: SampleData.items[0].id))
        }
        .environment(Router<HomeRoute>())
    }
}

#endif
