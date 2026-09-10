import Foundation

/// Tüm network çağrıları buradan geçer. JWT ekler, 401'de refresh dener,
/// backend hata formatını APIError'a çevirir.
actor APIClient {
    static let shared = APIClient()

    private let session = URLSession(configuration: .default)
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    enum Method: String { case get = "GET", post = "POST", patch = "PATCH" }

    private struct EmptyBody: Encodable {}

    /// Body gönderen istekler (POST/PATCH)
    func request<Body: Encodable, Response: Decodable>(
        path: String, method: Method, body: Body,
        queryItems: [URLQueryItem]? = nil, requiresAuth: Bool = true
    ) async throws -> Response {
        let data = try await rawRequest(path: path, method: method, body: body, queryItems: queryItems, requiresAuth: requiresAuth)
        do { return try decoder.decode(Response.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    /// Body göndermeyen istekler (GET vb.)
    func request<Response: Decodable>(
        path: String, method: Method,
        queryItems: [URLQueryItem]? = nil, requiresAuth: Bool = true
    ) async throws -> Response {
        let data = try await rawRequest(path: path, method: method, body: nil as EmptyBody?, queryItems: queryItems, requiresAuth: requiresAuth)
        do { return try decoder.decode(Response.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func rawRequest<Body: Encodable>(
        path: String, method: Method, body: Body?,
        queryItems: [URLQueryItem]?, requiresAuth: Bool, isRetry: Bool = false
    ) async throws -> Data {
        var url = APIConfig.baseURL.appendingPathComponent(path)
        if let queryItems, !queryItems.isEmpty {
            var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comp?.queryItems = queryItems
            url = comp?.url ?? url
        }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = await TokenStore.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body, !(body is EmptyBody) {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError.network(error) }

        guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            if requiresAuth, !isRetry, await TokenStore.shared.refreshToken != nil {
                if await AuthManager.shared.refreshAccessToken() {
                    return try await rawRequest(path: path, method: method, body: body, queryItems: queryItems, requiresAuth: requiresAuth, isRetry: true)
                }
            }
            await AuthManager.shared.logout()
            throw APIError.unauthorized
        case 403:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.detail ?? ""
            throw APIError.forbidden(msg)
        case 404:
            throw APIError.notFound
        case 409:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.detail ?? "Çakışma oluştu."
            throw APIError.conflict(msg)
        case 422:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.detail ?? "Bilgileri kontrol edin."
            throw APIError.validationError(msg)
        default:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.detail ?? ""
            throw APIError.server(msg)
        }
    }
}
