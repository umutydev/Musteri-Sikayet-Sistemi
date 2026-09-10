import Foundation

enum APIConfig {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:8000/api/v1")!
    #else
    static let baseURL = URL(string: "https://api.example.com/api/v1")!
    #endif
}
