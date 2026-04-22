import SwiftUI
import Combine

// MARK: - View state

enum PokemonListViewState {
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
    @Published var slideDirection: Edge = .trailing

    private let maxPages = 3
    private let pageSize = 20
    private let getPokemonPageUseCase: GetPokemonPageUseCase

    init(getPokemonPageUseCase: GetPokemonPageUseCase) {
        self.getPokemonPageUseCase = getPokemonPageUseCase
    }

    func onAppear() {
        if pokemons.isEmpty {
            loadPage(page: 0)
        }
    }

    func retry() {
        loadPage(page: currentPage)
    }

    func nextPage() {
        guard currentPage + 1 < maxPages else { return }
        slideDirection = .trailing
        loadPage(page: currentPage + 1)
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        slideDirection = .leading
        loadPage(page: currentPage - 1)
    }

    private func loadPage(page: Int) {
        state = .loading

        Task {
            do {
                let newPage = try await getPokemonPageUseCase.execute(page: page, pageSize: pageSize)

                withAnimation(.easeInOut(duration: 0.35)) {
                    pokemons = newPage
                    currentPage = page
                    state = newPage.isEmpty ? .empty : .loaded
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - View

struct PokemonListView: View {

    @StateObject var viewModel: PokemonListViewModel
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Namespace private var heroNamespace

    // Premium neutral gradient (light)
    private var lightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.96, blue: 0.98),
                Color(red: 0.88, green: 0.90, blue: 0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Premium neutral gradient (dark)
    private var darkGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.12, blue: 0.16),
                Color(red: 0.18, green: 0.20, blue: 0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {

            (isDarkMode ? darkGradient : lightGradient)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                header

                content
                    .transition(.move(edge: viewModel.slideDirection))

                paginationBar
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()

            Text("Pokédex")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Spacer()

            Button {
                withAnimation {
                    isDarkMode.toggle()
                }
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {

        switch viewModel.state {

        case .idle, .loading:
            Spacer()
            ProgressView()
                .scaleEffect(1.3)
            Spacer()

        case .empty:
            Spacer()
            Text("No hay resultados")
            Spacer()

        case .error(let message):
            Spacer()
            VStack(spacing: 16) {
                Text("Error")
                    .font(.title2)
                    .bold()

                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button {
                    viewModel.retry()
                } label: {
                    Text("Reintentar")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black)
                        )
                        .foregroundColor(.white)
                }
            }
            .padding()
            Spacer()

        case .loaded:
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(viewModel.pokemons, id: \.id) { pokemon in
                        NavigationLink {
                            PokemonDetailViewFactory.make(
                                id: pokemon.id,
                                name: pokemon.name,
                                namespace: heroNamespace
                            )
                        } label: {
                            PokemonRowView(
                                pokemon: pokemon,
                                isDarkMode: isDarkMode,
                                namespace: heroNamespace
                            )
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        VStack(spacing: 18) {

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == viewModel.currentPage ? Color.primary : Color.gray.opacity(0.4))
                        .frame(width: index == viewModel.currentPage ? 10 : 6,
                               height: index == viewModel.currentPage ? 10 : 6)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.currentPage)
                }
            }
            .padding(.top, 10)

            HStack(spacing: 50) {

                Button {
                    viewModel.previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.bold))
                }
                .disabled(viewModel.currentPage == 0)
                .opacity(viewModel.currentPage == 0 ? 0.3 : 1)

                Button {
                    viewModel.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.bold))
                }
                .disabled(viewModel.currentPage == 2)
                .opacity(viewModel.currentPage == 2 ? 0.3 : 1)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 50)
            .padding(.top, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isDarkMode ? 0.5 : 0.15), radius: 15, y: 8)
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Row

struct PokemonRowView: View {

    let pokemon: PokemonSummary
    let isDarkMode: Bool
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 18) {

            AsyncImage(url: pokemon.imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 75, height: 75)

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 75, height: 75)
                        .matchedGeometryEffect(id: pokemon.id, in: namespace)

                case .failure:
                    Image(systemName: "questionmark")

                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(pokemon.name)
                    .font(.system(size: 22, weight: .semibold))

                Text("#\(pokemon.id)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
        .shadow(color: .black.opacity(isDarkMode ? 0.5 : 0.08), radius: 10, y: 6)
    }
}

// MARK: - Factory

enum PokemonListViewFactory {
    static func make() -> some View {
        let client = URLSessionHTTPClient()
        let repository = RemotePokemonListRepository(client: client)
        let useCase = DefaultGetPokemonPageUseCase(repository: repository)
        let viewModel = PokemonListViewModel(getPokemonPageUseCase: useCase)

        return NavigationStack {
            PokemonListView(viewModel: viewModel)
        }
    }
}
