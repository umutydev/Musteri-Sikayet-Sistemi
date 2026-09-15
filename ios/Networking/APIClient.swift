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

    enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }
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
    /// Yanit govdesi beklemeyen istekler icin (DELETE, 204 No Content vb.)
    func requestVoid(
        path: String,
        method: Method,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws {
        _ = try await rawRequest(
            path: path, method: method, body: nil as EmptyBody?,
            queryItems: queryItems, requiresAuth: requiresAuth
        )
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
    /// Multipart/form-data ile dosya yukler.
    /// JSON gonderen request() fonksiyonundan ayri tutuldu cunku govde formati tamamen farkli.
    func upload<Response: Decodable>(
        path: String,
        fileName: String,
        contentType: String,
        data: Data,
        fieldName: String = "file"
    ) async throws -> Response {
        let url = APIConfig.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        // Boundary: govdedeki bolumleri ayiran benzersiz isaretci
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = await TokenStore.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: req)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            do { return try decoder.decode(Response.self, from: responseData) }
            catch { throw APIError.decoding(error) }
        case 400:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: responseData))?.detail
                ?? "Dosya yüklenemedi."
            throw APIError.validationError(msg)
        case 401:
            await AuthManager.shared.logout()
            throw APIError.unauthorized
        case 403:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: responseData))?.detail ?? ""
            throw APIError.forbidden(msg)
        case 409:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: responseData))?.detail ?? "Çakışma oluştu."
            throw APIError.conflict(msg)
        default:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: responseData))?.detail ?? ""
            throw APIError.server(msg)
        }
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
