//
//  JSON-RPC.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 6/9/24.
//

import Foundation

/// A request made using JSON
///
/// Note that if this is a request made from Swift to Node, all values in ``params`` must be `Encodable`.
public struct JSONRequest: Encodable {
    /// The method to call
    public var method: String
    /// Parameters, if any
    public var params: [String: Any]?
    /// An ID to associate with this request, if it expects a return value
    public var id: String?

    /// Creates a JSON Request
    public init(method: String, params: [String: any Encodable]? = nil, id: String? = nil) {
        self.method = method
        self.params = params
        self.id = id
    }

    enum Keys: CodingKey {
        case method
        case params
        case id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(method, forKey: .method)

        if let params {
            var anyCodableParams: [String: AnyEncodable]? = [:]
            for (key, value) in params {
                anyCodableParams?[key] = .init(value)
            }
            try container.encode(anyCodableParams, forKey: .params)
        }

        if let id {
            try container.encode(id, forKey: .id)
        }
    }

    /// Decodes a JSON request
    static func decode(from data: Data) throws -> JSONRequest {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let object = object as? [String: Any],
              let method = object["method"] as? String
        else {
            print("Could not parse top level JSON")
            throw JSONError.invalidJson
        }

        var request = JSONRequest(method: method)

        if let id = object["id"] as? String,
           UUID(uuidString: id) != nil {
            request.id = id
        }

        if let params = object["params"] as? [String: Any] {
            request.params = params
        }

        return request
    }
}

/// A response made using JSON
///
/// Note that if this is a response from Swift to Node, ``result`` must be `Encodable`.
public struct JSONResponse: Encodable {
    public var result: Any?
    public var error: JSONResponseError?
    public var id: String

    /// Creates a JSON response
    init(result: (any Encodable)? = nil, error: JSONResponseError? = nil, id: String) {
        self.result = result
        self.error = error
        self.id = id
    }

    /// Decodes a response from data
    static func decode(from data: Data) throws -> JSONResponse {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let object = object as? [String: Any],
              let id = object["id"] as? String,
              UUID(uuidString: id) != nil
        else {
            print("Could not parse top level JSON")
            throw JSONError.invalidJson
        }

        var response = JSONResponse(id: id)

        response.result = object["result"]
        if let rawError = object["error"],
           let encodedError = try? JSONSerialization.data(withJSONObject: rawError, options: []) {
            response.error = try JSONDecoder().decode(JSONResponseError.self, from: encodedError)
        }

        return response
    }

    enum Keys: CodingKey {
        case result
        case error
        case id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(id, forKey: .id)
        if let result {
            try container.encode(AnyEncodable(result), forKey: .result)
        }
        if let error {
            try container.encode(error, forKey: .error)
        }
    }
}

/// An error in JSON response
public struct JSONResponseError: Error, Codable {
    public var code: Int
    public var message: String
}

/// An error in sending or receiving JSON response
public enum JSONError: Error {
    case invalidJson
}

// AnyCodable struct to handle Any type
public struct AnyEncodable: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        if let codableValue = value as? any Codable {
            try codableValue.encode(to: encoder)
            return
        }

        var container = encoder.singleValueContainer()
        switch value {
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyEncodable($0) })
        case let dictionaryValue as [String: Any]:
            try container.encode(dictionaryValue.mapValues { AnyEncodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}
