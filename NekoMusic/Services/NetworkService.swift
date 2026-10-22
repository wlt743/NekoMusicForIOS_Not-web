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
            let nsError = error as NSError
            if nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost {
                return "服务器繁忙，请稍后再试"
            }
            return "网络错误: \(error.localizedDescription)"
        case .serverBusy: return "服务器繁忙，请稍后再试"
        }
    }
}

/// 统一网络层。
///
/// 后端要求：
/// 1. 所有请求都带客户端识别头（否则会被判成爬虫，返回 403 / SEO 页面）；
/// 2. 除白名单外的接口都要带一次性 `X-Neko-Nonce`；
/// 3. nonce 失效 / 重放返回 409，客户端应换一个 nonce 重试一次。
class NetworkService {
    static let shared = NetworkService()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.httpAdditionalHeaders = APIConfig.clientHeaders
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable>(url: String, token: String? = nil) async throws -> T {
        let data = try await send(url: url, method: "GET", body: nil, token: token)
        return try decode(T.self, from: data)
    }

    func post<T: Decodable>(url: String, body: Encodable, token: String? = nil) async throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(body)
        let responseData = try await send(url: url, method: "POST", body: data, token: token)
        return try decode(T.self, from: responseData)
    }

    func delete<T: Decodable>(url: String, token: String? = nil) async throws -> T {
        let data = try await send(url: url, method: "DELETE", body: nil, token: token)
        return try decode(T.self, from: data)
    }

    func getRawString(url: String, token: String? = nil) async throws -> String {
        let data = try await send(url: url, method: "GET", body: nil, token: token)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 供自定义图片加载器使用：带客户端头拉取二进制资源
    func fetchData(url: String) async throws -> Data {
        try await send(url: url, method: "GET", body: nil, token: nil)
    }

    /// 需要手工解析 JSON 的场景（音乐接口的字段比较松散）
    func rawGet(url: String, token: String? = nil) async throws -> Data {
        try await send(url: url, method: "GET", body: nil, token: token)
    }

    func rawPost(url: String, json: [String: Any], token: String? = nil) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await send(url: url, method: "POST", body: body, token: token)
    }

    // MARK: - Core

    private func send(url: String, method: String, body: Data?, token: String?) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }

        // 409 表示 nonce 缺失 / 过期 / 重放，换一个再试一次
        for attempt in 0...1 {
            var request = URLRequest(url: requestURL)
            request.httpMethod = method
            request.timeoutInterval = 60

            for (key, value) in APIConfig.clientHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            if method != "GET" {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if let token = token {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            }
            if let body = body {
                request.httpBody = body
            }

            let path = requestURL.path
            if APIConfig.requiresNonce(path: path) {
                let nonce = try await NonceService.shared.nextNonce(forWrite: method != "GET")
                request.setValue(nonce, forHTTPHeaderField: "X-Neko-Nonce")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.noData
            }

            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            if httpResponse.statusCode == 409 && attempt == 0 {
                continue
            }
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 503 {
                throw NetworkError.serverBusy
            }
            if !(200...299).contains(httpResponse.statusCode) {
                let msg = Self.message(from: data) ?? "请求失败（\(httpResponse.statusCode)）"
                NSLog("[NekoAPI] %@ %@ -> %d %@", method, url, httpResponse.statusCode, msg)
                throw NetworkError.serverError(msg)
            }

            return data
        }

        throw NetworkError.serverBusy
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    static func message(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let error = json["error"] as? String, !error.isEmpty {
            return error
        }
        return nil
    }
}
