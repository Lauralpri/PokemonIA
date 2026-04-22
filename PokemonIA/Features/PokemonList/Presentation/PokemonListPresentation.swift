import SwiftUI
import Combine

// MARK: - View state

enum PokemonListViewState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(String)
}

// MARK: - ViewModel

@MainActor
final class PokemonListViewModel: ObservableObject {

    @Published var state: PokemonListViewState = .idle
    @Published var pokemons: [PokemonSummary] = []
    @Published var currentPage: Int = 0
    @Published var pageSize: Int = 20
    @Published var isLoadingPage: Bool = false

    private let maxPagesToDemo = 3
    private let getPokemonPageUseCase: GetPokemonPageUseCase

    init(getPokemonPageUseCase: GetPokemonPageUseCase) {
        self.getPokemonPageUseCase = getPokemonPageUseCase
    }

    func onAppear() {
        if pokemons.isEmpty {
            loadPage(page: 0)
        }
    }

    func reload() {
        pokemons = []
        currentPage = 0
        loadPage(page: 0)
    }

    func loadNextPageIfNeeded(currentItem item: PokemonSummary?) {
        guard let item = item else { return }
        guard let index = pokemons.firstIndex(where: { $0.id == item.id }) else { return }

        let thresholdIndex = pokemons.index(pokemons.endIndex, offsetBy: -5)
        if index >= thresholdIndex {
            loadNextPage()
        }
    }

    func loadNextPage() {
        guard !isLoadingPage else { return }
        guard currentPage + 1 < maxPagesToDemo else { return }
        loadPage(page: currentPage + 1, append: true)
    }

    private func loadPage(page: Int, append: Bool = false) {
        state = .loading
        isLoadingPage = true

        Task {
            do {
                let newPage = try await getPokemonPageUseCase.execute(page: page, pageSize: pageSize)

                if append {
                    self.pokemons.append(contentsOf: newPage)
                } else {
                    self.pokemons = newPage
                }

                self.currentPage = page
                if self.pokemons.isEmpty {
                    self.state = .empty
                } else {
                    self.state = .loaded
                }
            } catch {
                let message: String
                if let networkError = error as? NetworkError {
                    message = networkError.localizedDescription
                } else {
                    message = error.localizedDescription
                }
                self.state = .error(message)
            }
            self.isLoadingPage = false
        }
    }
}

// MARK: - SwiftUI View

struct PokemonListView: View {
    @StateObject var viewModel: PokemonListViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pokémon")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text("Pokémon")
                                .font(.headline)
                            Text("Página \(viewModel.currentPage + 1) de 3")
                                .font(.caption)
                        }
                    }
                }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Cargando...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            VStack(spacing: 12) {
                Text("No hay resultados")
                    .font(.headline)
                Button("Reintentar") {
                    viewModel.reload()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(spacing: 12) {
                Text("Ha ocurrido un error")
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Reintentar") {
                    viewModel.reload()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            listView
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.pokemons, id: \.id) { pokemon in
                NavigationLink {
                    PokemonDetailViewFactory.make(id: pokemon.id, name: pokemon.name)
                } label: {
                    PokemonRowView(pokemon: pokemon)
                        .onAppear {
                            viewModel.loadNextPageIfNeeded(currentItem: pokemon)
                        }
                }
            }

            if viewModel.isLoadingPage {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Row

struct PokemonRowView: View {
    let pokemon: PokemonSummary

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: pokemon.imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 56, height: 56)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                case .failure:
                    Image(systemName: "questionmark.square")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            Text("#\(pokemon.id)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(pokemon.name)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Factory para inyección de dependencias

enum PokemonListViewFactory {
    static func make() -> some View {
        let client = URLSessionHTTPClient()
        let repository = RemotePokemonListRepository(client: client)
        let useCase = DefaultGetPokemonPageUseCase(repository: repository)
        let viewModel = PokemonListViewModel(getPokemonPageUseCase: useCase)
        return PokemonListView(viewModel: viewModel)
    }
}
