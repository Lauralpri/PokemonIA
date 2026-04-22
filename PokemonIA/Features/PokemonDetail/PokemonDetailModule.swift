import SwiftUI
import Foundation
import Combine

// MARK: - Data (DTOs)

struct PokemonDetailDTO: Decodable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let sprites: PokemonSpritesDTO
    let types: [PokemonTypeSlotDTO]
}

struct PokemonSpritesDTO: Decodable {
    let frontDefault: String?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
    }
}

struct PokemonTypeSlotDTO: Decodable {
    let slot: Int
    let type: PokemonTypeDTO
}

struct PokemonTypeDTO: Decodable {
    let name: String
}

// MARK: - Domain

struct PokemonDetailModel {
    let id: Int
    let name: String
    let imageURL: URL?
    let types: [String]
    let height: Double
    let weight: Double
}

protocol PokemonDetailRepository {
    func getDetail(id: Int) async throws -> PokemonDetailModel
}

final class RemotePokemonDetailRepository: PokemonDetailRepository {

    private let client: HTTPClient
    private let baseURL = URL(string: "https://pokeapi.co/api/v2")!

    init(client: HTTPClient) {
        self.client = client
    }

    func getDetail(id: Int) async throws -> PokemonDetailModel {
        let url = baseURL.appendingPathComponent("pokemon/\(id)")
        let dto = try await client.get(url, as: PokemonDetailDTO.self)

        let imageURL = dto.sprites.frontDefault.flatMap(URL.init(string:))
        let types = dto.types
            .sorted { $0.slot < $1.slot }
            .map { $0.type.name.capitalized }

        return PokemonDetailModel(
            id: dto.id,
            name: dto.name.capitalized,
            imageURL: imageURL,
            types: types,
            height: Double(dto.height) / 10,
            weight: Double(dto.weight) / 10
        )
    }
}

// MARK: - Use Case

protocol GetPokemonDetailUseCase {
    func execute(id: Int) async throws -> PokemonDetailModel
}

final class DefaultGetPokemonDetailUseCase: GetPokemonDetailUseCase {

    private let repository: PokemonDetailRepository

    init(repository: PokemonDetailRepository) {
        self.repository = repository
    }

    func execute(id: Int) async throws -> PokemonDetailModel {
        try await repository.getDetail(id: id)
    }
}

// MARK: - Presentation

enum PokemonDetailViewState {
    case idle
    case loading
    case loaded(PokemonDetailModel)
    case error(String)
}

@MainActor
final class PokemonDetailViewModel: ObservableObject {

    @Published var state: PokemonDetailViewState = .idle

    private let id: Int
    private let getDetailUseCase: GetPokemonDetailUseCase

    init(id: Int, getDetailUseCase: GetPokemonDetailUseCase) {
        self.id = id
        self.getDetailUseCase = getDetailUseCase
    }

    func onAppear() {
        if case .idle = state {
            load()
        }
    }

    private func load() {
        state = .loading

        Task {
            do {
                let detail = try await getDetailUseCase.execute(id: id)
                withAnimation(.easeInOut(duration: 0.4)) {
                    state = .loaded(detail)
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - View

struct PokemonDetailView: View {

    @StateObject var viewModel: PokemonDetailViewModel
    @AppStorage("isDarkMode") private var isDarkMode = false

    @State private var showImage = false
    @State private var showTitle = false
    @State private var showTypes = false
    @State private var showStats = false

    let name: String

    private var lightBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.93, green: 0.94, blue: 0.97)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var darkBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.15, green: 0.17, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {

            (isDarkMode ? darkBackground : lightBackground)
                .ignoresSafeArea()

            content
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
    }

    @ViewBuilder
    private var content: some View {

        switch viewModel.state {

        case .idle, .loading:
            ProgressView()
                .scaleEffect(1.4)

        case .error(let message):
            VStack {
                Text("Error")
                Text(message)
            }

        case .loaded(let model):

            ScrollView {
                VStack(spacing: 30) {

                    Spacer(minLength: 30)

                    AsyncImage(url: model.imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 180)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .scaleEffect(showImage ? 1 : 0.6)
                                .opacity(showImage ? 1 : 0)

                        case .failure:
                            Image(systemName: "questionmark")

                        @unknown default:
                            EmptyView()
                        }
                    }

                    Text("#\(model.id)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 10)

                    Text(model.name)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 10)

                    HStack(spacing: 14) {
                        ForEach(model.types, id: \.self) { type in
                            Text(type)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white)
                                )
                        }
                    }
                    .opacity(showTypes ? 1 : 0)
                    .offset(y: showTypes ? 0 : 15)

                    VStack(spacing: 12) {
                        Text("Altura: \(String(format: "%.1f", model.height)) m")
                        Text("Peso: \(String(format: "%.1f", model.weight)) kg")
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                    )
                    .padding(.horizontal, 40)
                    .shadow(color: .black.opacity(isDarkMode ? 0.4 : 0.08), radius: 15, y: 8)
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 20)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
                .onAppear {
                    showImage = false
                    showTitle = false
                    showTypes = false
                    showStats = false

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showImage = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showTitle = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showTypes = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showStats = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Factory

enum PokemonDetailViewFactory {

    static func make(id: Int, name: String) -> some View {
        let client = URLSessionHTTPClient()
        let repository = RemotePokemonDetailRepository(client: client)
        let useCase = DefaultGetPokemonDetailUseCase(repository: repository)
        let viewModel = PokemonDetailViewModel(id: id, getDetailUseCase: useCase)

        return PokemonDetailView(viewModel: viewModel, name: name)
    }
}
