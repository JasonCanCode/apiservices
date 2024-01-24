import Foundation

/// A data response encapsulation DTO
/// - Tag: APIResponse
internal struct APIResponse<T: Decodable>: Decodable {
    private let object: APIResponseWithError<T>
    internal var value: T {
        get throws {
            switch object.result {
            case .success(let object):
                return object
            case .failure(let error):
                throw error
            }
        }
    }
    
    fileprivate enum CodingKeys: String, CodingKey {
        case object = "d"
    }
}

private struct APIResponseWithError<T: Decodable>: Decodable {
    fileprivate let result: Result<T, Error>

    /// This is to make sure we aren't dependent on the casing of the keys.
    private enum CodingKeys: String, CodingKey {
        case errorCode
        case errorText
        case data
        case errorCodeAlt = "ErrorCode"
        case errorTextAlt = "ErrorText"
        case dataAlt = "Data"
    }
    
    fileprivate init(from decoder: Decoder) throws {
        do {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
                // If we can't create the container then T is an array type so don't try to read
                // the error code/message
                let object = try T(from: decoder)
                result = .success(object)
                return
            }
            
            let errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
                ?? container.decodeIfPresent(Int.self, forKey: .errorCodeAlt)
                ?? 0
            
            guard errorCode == 0 || errorCode == 200 else {
                let errorMessage = try? container.decodeIfPresent(String.self, forKey: .errorText)
                    ?? container.decodeIfPresent(String.self, forKey: .errorTextAlt)
                    ?? NSLocalizedString("An unknown error occurred", comment: "An unknown error occurred")
                result = .failure(APIError.server(code: errorCode, message: errorMessage))
                return
            }
            
            do {
                let object = try Self.decodeData(from: decoder)
                result = .success(object)
            } catch let dataError {
                do {
                    let object = try T(from: decoder)
                    result = .success(object)
                } catch {
                    switch dataError {
                    case let DecodingError.keyNotFound(key, _) where Self.isDataKey(key):
                        throw error
                    default:
                        throw dataError
                    }
                }
            }
        } catch {
            result = .failure(error)
        }
    }

    private static func decodeData(from decoder: Decoder) throws -> T {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            return try container.decode(T.self, forKey: .data)
        } catch {
            return try container.decode(T.self, forKey: .dataAlt)
        }
    }

    private static func isDataKey(_ key: CodingKey) -> Bool {
        switch key {
        case CodingKeys.data, CodingKeys.dataAlt:
            return true
        default:
            return false
        }
    }
}
