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
    let height: Double // metros
    let weight: Double // kg
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

        // La API devuelve altura en decímetros y peso en hectogramos.
        let heightMeters = Double(dto.height) / 10.0
        let weightKg = Double(dto.weight) / 10.0

        return PokemonDetailModel(
            id: dto.id,
            name: dto.name.capitalized,
            imageURL: imageURL,
            types: types,
            height: heightMeters,
            weight: weightKg
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

    func retry() {
        load()
    }

    private func load() {
        state = .loading

        Task {
            do {
                let detail = try await getDetailUseCase.execute(id: id)
                self.state = .loaded(detail)
            } catch {
                let message: String
                if let networkError = error as? NetworkError {
                    message = networkError.localizedDescription
                } else {
                    message = error.localizedDescription
                }
                // Requisito: error controlado, sin crash, con opción de reintento
                self.state = .error(message)
            }
        }
    }
}

// MARK: - View

struct PokemonDetailView: View {
    @StateObject var viewModel: PokemonDetailViewModel
    let name: String

    var body: some View {
        content
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
            VStack {
                Spacer()
                ProgressView("Cargando detalle...")
                Spacer()
            }

        case .error(let message):
            VStack(spacing: 12) {
                Text("No se pudo cargar el detalle")
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Reintentar") {
                    viewModel.retry()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let model):
            ScrollView {
                VStack(spacing: 16) {
                    AsyncImage(url: model.imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 160, height: 160)
                        case .failure:
                            Image(systemName: "questionmark.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }

                    Text("#\(model.id) \(model.name)")
                        .font(.title2)
                        .bold()

                    if !model.types.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(model.types, id: \.self) { type in
                                Text(type)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Altura: \(String(format: "%.1f", model.height)) m")
                        Text("Peso: \(String(format: "%.1f", model.weight)) kg")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
            }

        case .idle:
            EmptyView()
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
