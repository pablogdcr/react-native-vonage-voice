//
//  NetworkController.swift
//  VonageSDKClientVOIPExample
//
//  Created by Mehboob Alam on 27.06.23.
//

import Foundation
import Combine

/// API TYPE
protocol ApiType {
    var url: URL {get}
    var method: String {get}
    var headers: [String: String] {get}
    var body: Encodable? {get}
}

/// Refresh Token
struct RefreshTokenAPI: ApiType {
    var body: (any Encodable)?
    var url: URL
    var method: String = "POST"
    var headers: [String : String]

    init(token: String, url: String) {
        headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        self.url = URL(string: url)!
    }
}

class NetworkController {
    func sendRequest<type: Decodable>(apiType: any ApiType) -> AnyPublisher<type, Error> {
        var request = URLRequest(url: apiType.url)
        request.httpMethod = apiType.method
        request.allHTTPHeaderFields = apiType.headers
        do {
            if let body = apiType.body {
                request.httpBody = try JSONEncoder().encode(body)
            }
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        return URLSession
            .shared
            .dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    let error = try? JSONSerialization.jsonObject(with: data)
                    print(error ?? "unknown")
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: type.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

struct TokenResponseData: Decodable {
    let token: String
}

/// NetworkData Models
struct TokenResponse: Decodable {
    let data: TokenResponseData
}

struct RefreshTokenRequest: Encodable {
    let token: String
    let type: String = "refresh"
}
