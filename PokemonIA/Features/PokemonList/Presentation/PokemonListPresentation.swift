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
    @State private var leftPressed = false
    @State private var rightPressed = false

    // Premium green gradient
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.40, green: 0.75, blue: 0.55),
            Color(red: 0.85, green: 0.97, blue: 0.92)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {

            backgroundGradient
                .ignoresSafeArea()

            // Subtle Pokéball watermark
            Image(systemName: "circle.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 350)
                .foregroundColor(.white.opacity(0.05))
                .offset(y: 200)

            VStack(spacing: 0) {

                Text("Pokédex")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                content
                    .transition(.move(edge: viewModel.slideDirection))

                paginationBar
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {

        switch viewModel.state {

        case .idle, .loading:
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Spacer()

        case .empty:
            Spacer()
            Text("No hay resultados")
            Spacer()

        case .error(let message):
            Spacer()
            VStack {
                Text("Error")
                Text(message)
            }
            Spacer()

        case .loaded:
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.pokemons, id: \.id) { pokemon in
                        NavigationLink {
                            PokemonDetailViewFactory.make(id: pokemon.id, name: pokemon.name)
                        } label: {
                            PokemonRowView(pokemon: pokemon)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(24)
                                .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
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

    // MARK: - Pagination Bar (Floating Capsule)

    private var paginationBar: some View {
        HStack(spacing: 50) {

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    leftPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    leftPressed = false
                }
                viewModel.previousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.bold))
                    .scaleEffect(leftPressed ? 0.7 : 1)
            }
            .disabled(viewModel.currentPage == 0)
            .opacity(viewModel.currentPage == 0 ? 0.3 : 1)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    rightPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    rightPressed = false
                }
                viewModel.nextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2.weight(.bold))
                    .scaleEffect(rightPressed ? 0.7 : 1)
            }
            .disabled(viewModel.currentPage == 2)
            .opacity(viewModel.currentPage == 2 ? 0.3 : 1)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 50)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
        .padding(.bottom, 30)
    }
}

// MARK: - Row

struct PokemonRowView: View {

    let pokemon: PokemonSummary

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
                        .transition(.scale)

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
