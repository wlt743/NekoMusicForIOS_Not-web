import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case networkError(Error)
    case serverBusy
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .noData: return "没有数据"
        case .decodingError(let error): return "数据解析错误: \(error.localizedDescription)"
        case .serverError(let message): return message
        case .unauthorized: return "未授权，请重新登录"
        case .networkError(let error):
            // Check if it's a timeout error
            let nsError = error as NSError
            if nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost {
                return "服务器繁忙，请稍后再试"
            }
            return "网络错误: \(error.localizedDescription)"
        case .serverBusy: return "服务器繁忙，请稍后再试"
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        // API returns camelCase keys, no conversion needed
    }
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(url: String, token: String? = nil) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Fallback: try without snake_case conversion
            let fallbackDecoder = JSONDecoder()
            do {
                return try fallbackDecoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        }
    }
    
    func post<T: Decodable>(url: String, body: Encodable, token: String? = nil) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let fallbackDecoder = JSONDecoder()
            do {
                return try fallbackDecoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        }
    }
    
    func delete<T: Decodable>(url: String, token: String? = nil) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let fallbackDecoder = JSONDecoder()
            do {
                return try fallbackDecoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        }
    }
    
    func getRawString(url: String, token: String? = nil) async throws -> String {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
