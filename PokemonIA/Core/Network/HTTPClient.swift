import Foundation

// MARK: - Core network error

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case transport(Error)
    case invalidResponse
    case statusCode(Int)
    case decoding(Error)
    case noInternet

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .transport(let error):
            return "Error de red: \(error.localizedDescription)"
        case .invalidResponse:
            return "Respuesta no válida"
        case .statusCode(let code):
            return "Error HTTP \(code)"
        case .decoding:
            return "Error al interpretar los datos"
        case .noInternet:
            return "Sin conexión a internet"
        }
    }
}

// MARK: - HTTPClient abstraction

protocol HTTPClient {
    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T
}

// MARK: - Concrete implementation with URLSession

final class URLSessionHTTPClient: HTTPClient {
    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        // En un proyecto real podríamos usar NWPathMonitor para detectar mejor
        // la falta de conexión. Aquí simplificamos y dejamos que el error
        // de transporte se traduzca después.
        let request = URLRequest(url: url)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 0 {
                    throw NetworkError.noInternet
                }
                throw NetworkError.statusCode(httpResponse.statusCode)
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                throw NetworkError.decoding(error)
            }
        } catch {
            // Aquí podrías inspeccionar el error de URLSession para detectar
            // específicamente "no hay internet" (NSURLErrorNotConnectedToInternet),
            // lo cual nos viene bien para el requisito de modo avión.
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorNotConnectedToInternet {
                throw NetworkError.noInternet
            }
            throw NetworkError.transport(error)
        }
    }
}
