import Foundation

// MARK: - Use case para obtener una página de Pokémon

protocol GetPokemonPageUseCase {
    func execute(page: Int, pageSize: Int) async throws -> [PokemonSummary]
}

final class DefaultGetPokemonPageUseCase: GetPokemonPageUseCase {
    private let repository: PokemonListRepository

    init(repository: PokemonListRepository) {
        self.repository = repository
    }

    func execute(page: Int, pageSize: Int) async throws -> [PokemonSummary] {
        // Paginación basada en limit + offset:
        // page 0 -> offset 0
        // page 1 -> offset pageSize
        // etc.
        let offset = page * pageSize
        return try await repository.getPage(limit: pageSize, offset: offset)
    }
}
