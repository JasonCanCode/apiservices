import Foundation

/// Convert a `Data` object into an array of the associated `Decodable` objects.
/// If there is any issue decoding into an array of objects, an empty array will be returned instead.
/// - Parameters:
///   - failableArrayData: A `Data` object that may be serialized into JSON and mapped to an array of `Decodable` objects.
///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
/// - Returns: An array of the associated `Decodable` objects.
public func parse<T: Decodable>(
    failableArrayData: Data?,
    keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
) throws -> [T] {

    let failable: [FailableDecodable<T>] = try parse(
        jsonData: failableArrayData,
        keyDecodingStrategy: keyDecodingStrategy
    )
    return failable.compactMap { $0.base }
}

// MARK: - JSON Parsing

/// Convert a `Data` object into a `Decodable` object.
/// - Parameters:
///   - jsonData: A `Data` object that may be serialized into JSON and mapped to `Decodable` objects.
///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
/// - Returns: A `Decodable` object created from the provided data.
public func parse<T: Decodable>(
    jsonData: Data?,
    keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
) throws -> T {
    
    do {
        if let data = jsonData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = Configuration.dateDecodingStrategy
            decoder.keyDecodingStrategy = keyDecodingStrategy
            return try decoder.decode(T.self, from: data)
            
        } else {
            throw APIError.noData
        }
    } catch {
        Configuration.errorLogger.logError(error)
        throw error
    }
}

/// Convert a `Data` object into an array of the associated `Decodable` objects using the provided initializer.
/// - Parameters:
///   - jsonArrayData: A `Data` object that can be serialized into an array of JSON.
///   - initializer: An initializer of the associated `Decodable` object.
/// - Returns: An array of the associated `Decodable` objects using the provided initializer.
public func parse<T>(jsonArrayData: Data?, initializer: (JSON) -> T?) throws -> [T] {
    
    do {
        if let data = jsonArrayData {
            
            if let unwrapped = jsonArray(fromResponseData: data) {
                return unwrapped.compactMap(initializer)
            } else {
                throw APIError.invalidData
            }
            
        } else {
            throw APIError.noData
        }
        
    } catch {
        Configuration.errorLogger.logError(error)
        throw error
    }
}

/// Convert data into ``JSON`` using common patterns expected of API responses.
/// - Parameter data: A `Data` object that can be serialized into ``JSON``.
/// - Returns: ``JSON`` if data parsing was successful.
public func json(fromResponseData data: Data) -> JSON? {
    jsonArray(fromResponseData: data)?.first
}

/// Convert data into an array of``JSON`` using common patterns expected of API responses.
/// - Parameter data: A `Data` object that can be serialized into an array of ``JSON``.
/// - Returns: An array of ``JSON`` if data parsing was successful.
public func jsonArray(fromResponseData data: Data) -> [JSON]? {
    do {
        let obj = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)

        guard let simpleJSON = obj as? JSON else {
            return obj as? [JSON]
        }
        return [simpleJSON]

    } catch {
        return nil
    }
}

// MARK: - Data Parsing Requests

public extension APIServiceType {

    /// Send a generated `URLRequest`, injected with the proper headers and body data,
    /// and return the response as the associated `Decodable` object on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - encodableBody: An `Encodable` object used to generate the data for the request body.
    ///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
    /// - Returns: The associated `Decodable` object created from the network response.
    /// - SeeAlso:
    ///   - ``performRequest(_:httpMethod:encodableBody:)``
    ///   - ``parse(jsonData:error:keyDecodingStrategy:)``
    @MainActor
    func requestDecodableObject<Body: Encodable, T: Decodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        encodableBody: Body,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) async throws -> T {
        let data = try await performRequest(resourcePath, httpMethod: httpMethod, encodableBody: encodableBody)
        return try parse(jsonData: data, keyDecodingStrategy: keyDecodingStrategy)
    }

    /// Send a generated `URLRequest`, injected with the proper headers and body data,
    /// and return the response as the associated `Decodable` object on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - paramData: Data to include in the `httpBody` of the generated request.
    ///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
    /// - Returns: The associated `Decodable` object created from the network response.
    /// - SeeAlso:
    ///   - ``performRequest(_:httpMethod:parameters:)``
    ///   - ``parse(jsonData:error:keyDecodingStrategy:)``
    @MainActor
    func requestDecodableObject<T: Decodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        paramData: Data? = nil,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) async throws -> T {
        let data = try await performRequest(resourcePath, httpMethod: httpMethod, paramData: paramData)
        return try parse(jsonData: data, keyDecodingStrategy: keyDecodingStrategy)
    }

    /// Send a generated `URLRequest`, injected with the proper headers and body data,
    /// and return the response as the associated `Decodable` object on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - parameters: An optional dictionary of information to be encoded as either JSON Data in the body or as a query string.
    ///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
    /// - Returns: The associated `Decodable` object created from the network response.
    /// - SeeAlso:
    ///   - ``performRequest(_:httpMethod:parameters:)``
    ///   - ``parse(jsonData:error:keyDecodingStrategy:)``
    @MainActor
    func requestDecodableObject<T: Decodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        parameters: JSON?,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) async throws -> T {
        let paramData = Self.requestBody(forParameters: parameters)
        return try await requestDecodableObject(
            resourcePath,
            httpMethod: httpMethod,
            paramData: paramData,
            keyDecodingStrategy: keyDecodingStrategy
        )
    }

    /// Send a generated `URLRequest`, injected with the proper headers and query data,
    /// and return the response as the associated `Decodable` object on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - queryItems: A dictionary of information to be converted to query items as part of the request.
    ///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
    /// - Returns: The associated `Decodable` object created from the network response.
    /// - SeeAlso:
    ///   - ``performRequest(_:httpMethod:queryItems:)``
    ///   - ``parse(jsonData:error:keyDecodingStrategy:)``
    @available(iOS 16.0, *)
    @MainActor
    func requestDecodableObject<T: Decodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        queryItems: JSON,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) async throws -> T {

        let data = try await performRequest(
            resourcePath,
            httpMethod: httpMethod,
            queryItems: queryItems
        )
        return try parse(jsonData: data, keyDecodingStrategy: keyDecodingStrategy)
    }

    /// Send a generated `URLRequest`, injected with the proper headers and body data, and return the response
    /// as an array of the associated `Decodable` objects on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - paramData: Data to include in the `httpBody` of the generated request.
    ///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
    /// - Returns: An array of associated `Decodable` objects created from the network response.
    /// - SeeAlso:
    ///   - ``performRequest(_:httpMethod:parameters:)``
    ///   - ``parse(failableArrayData:error:keyDecodingStrategy:)``
    @MainActor
    func requestFailableArray<T: Decodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        paramData: Data? = nil,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) async throws -> [T] {
        let data = try await performRequest(resourcePath, httpMethod: httpMethod, paramData: paramData)
        return try parse(failableArrayData: data, keyDecodingStrategy: keyDecodingStrategy)
    }

    /// Send a generated `URLRequest`, injected with the proper headers and body data, and return the response
    /// as an array of the associated `Decodable` objects on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - encodableBody: An `Encodable` object used to generate the data for the request body.
    ///   - keyDecodingStrategy: Used to determine how to decode a type’s coding keys from JSON keys. `.useDefaultKeys` by default.
    /// - Returns: The associated `Decodable` object created from the network response.
    /// - SeeAlso:
    ///   - ``performRequest(_:httpMethod:encodableBody:)``
    ///   - ``parse(failableArrayData:error:keyDecodingStrategy:)``
    @MainActor
    func requestFailableArray<Body: Encodable, T: Decodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        encodableBody: Body,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) async throws -> [T] {
        let data = try await performRequest(resourcePath, httpMethod: httpMethod, encodableBody: encodableBody)
        return try parse(failableArrayData: data, keyDecodingStrategy: keyDecodingStrategy)
    }
}

@objc public extension APIService {

    /// Send a generated `URLRequest`, injected with the proper headers and body data,
    /// and throw an error if the result cannot be mapped to a boolean that is true.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - parameters: An optional dictionary of information to be encoded as either JSON Data in the body or as a query string.
    @MainActor
    func performBoolRequest(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        parameters: JSON?
    ) async throws {
        let paramData = Self.requestBody(forParameters: parameters)
        let success: Bool = try await requestDecodableObject(
            resourcePath,
            httpMethod: httpMethod,
            paramData: paramData
        )

        if !success {
            throw APIError.failureResponse
        }
    }
}
