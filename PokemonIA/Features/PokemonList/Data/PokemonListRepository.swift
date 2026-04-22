import Foundation

// MARK: - Domain models (lista)

struct PokemonSummary {
    let id: Int
    let name: String
    let imageURL: URL?
}

// MARK: - Repository abstraction

protocol PokemonListRepository {
    func getPage(limit: Int, offset: Int) async throws -> [PokemonSummary]
}

// MARK: - Remote implementation

final class RemotePokemonListRepository: PokemonListRepository {
    private let client: HTTPClient
    private let baseURL = URL(string: "https://pokeapi.co/api/v2")!

    init(client: HTTPClient) {
        self.client = client
    }

    func getPage(limit: Int, offset: Int) async throws -> [PokemonSummary] {
        var components = URLComponents(url: baseURL.appendingPathComponent("pokemon"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            .init(name: "limit", value: String(limit)),
            .init(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        let dto = try await client.get(url, as: PokemonListResponseDTO.self)

        return dto.results.enumerated().compactMap { index, item in
            // En la lista PokeAPI solo te da el nombre y la URL al detalle.
            // Vamos a extraer el id del Pokémon a partir de la URL:
            // Ej: https://pokeapi.co/api/v2/pokemon/1/  -> id = 1
            let id = extractID(from: item.url)
            let imageURL = id.flatMap { id in
                URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")
            }

            guard let pokemonID = id else { return nil }

            return PokemonSummary(
                id: pokemonID,
                name: item.name.capitalized,
                imageURL: imageURL
            )
        }
    }

    private func extractID(from urlString: String) -> Int? {
        guard let url = URL(string: urlString) else { return nil }
        let components = url.pathComponents.filter { !$0.isEmpty }
        // pathComponents para ".../pokemon/1/" -> ["pokemon", "1"]
        guard let last = components.last, let id = Int(last) else {
            return nil
        }
        return id
    }
}
