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
                withAnimation(.spring()) {
                    self.state = .loaded(detail)
                }
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - View

struct PokemonDetailView: View {

    @StateObject var viewModel: PokemonDetailViewModel
    let name: String

    private let pastelGreen = Color(red: 0.80, green: 0.93, blue: 0.85)

    var body: some View {
        ZStack {
            pastelGreen.opacity(0.4)
                .ignoresSafeArea()

            content
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {

        case .idle, .loading:
            ProgressView("Cargando...")
                .scaleEffect(1.3)

        case .error(let message):
            VStack(spacing: 16) {
                Text("Error")
                    .font(.title2)
                Text(message)
                Button("Reintentar") {
                    viewModel.onAppear()
                }
            }

        case .loaded(let model):
            ScrollView {
                VStack(spacing: 24) {

                    AsyncImage(url: model.imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 150)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 180)
                                .scaleEffect(1.1)
                                .transition(.scale)

                        case .failure:
                            Image(systemName: "questionmark.circle")

                        @unknown default:
                            EmptyView()
                        }
                    }

                    Text("#\(model.id)")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text(model.name)
                        .font(.largeTitle)
                        .bold()

                    HStack(spacing: 12) {
                        ForEach(model.types, id: \.self) { type in
                            Text(type)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                        }
                    }

                    VStack(spacing: 8) {
                        Text("Altura: \(String(format: "%.1f", model.height)) m")
                        Text("Peso: \(String(format: "%.1f", model.weight)) kg")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 4)
                }
                .padding()
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
