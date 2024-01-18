import Foundation

/// It is best to be clear what the intended use of this dictionary is
public typealias JSON = [AnyHashable: Any]

// From: https://stackoverflow.com/a/46369152

/// A wrapper type that attempts to decode a given value; storing `nil` if unsuccessful.
public struct FailableDecodable<Base: Decodable>: Decodable {
    public let base: Base?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        do {
            base = try container.decode(Base.self)
        } catch {
            base = nil
        }
    }
}

public extension JSONDecoder.KeyDecodingStrategy {

    static let convertFromUpperCamelCase = JSONDecoder.KeyDecodingStrategy.custom { keys -> CodingKey in
        var key = AnyCodingKey(keys.last!)

        // lowercase first letter
        if let firstChar = key.stringValue.first {
            let index = key.stringValue.startIndex
            key.stringValue.replaceSubrange(
                index ... index, with: String(firstChar).lowercased()
            )
        }

        return key
    }

    private struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(_ base: CodingKey) {
            self.init(stringValue: base.stringValue, intValue: base.intValue)
        }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }

        init(stringValue: String, intValue: Int?) {
            self.stringValue = stringValue
            self.intValue = intValue
        }
    }
}
