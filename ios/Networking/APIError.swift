import Foundation

struct APIErrorResponse: Codable {
    let detail: String
}

enum APIError: LocalizedError {
    case unauthorized
    case forbidden(String)
    case notFound
    case conflict(String)
    case validationError(String)
    case server(String)
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Oturumunuzun süresi doldu, lütfen tekrar giriş yapın."
        case .forbidden(let m): return m.isEmpty ? "Bu işlem için yetkiniz yok." : m
        case .notFound: return "Kayıt bulunamadı."
        case .conflict(let m): return m
        case .validationError(let m): return m
        case .server(let m): return m.isEmpty ? "Sunucu hatası oluştu." : m
        case .network: return "İnternet bağlantınızı kontrol edin."
        case .decoding: return "Sunucudan beklenmeyen bir yanıt geldi."
        }
    }
}
