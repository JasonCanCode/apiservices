import Foundation

#if DEBUG

/// Use this to print out helpful information on network requests when debugging.
/// The functions return strings so you can decide whether to use print statements or custom breakpoints to log them.
///
/// - Note: Use is restricted to DEBUG builds only.
public enum NetworkLogger {
    
    static func cURLLog(request: URLRequest) -> String {
        "\n🌎 \(request.cURL)\n"
    }
    
    /// Print an outgoing request to the console with a print statement or custom breakpoint
    static func requestLog(_ request: URLRequest, includeHeaders: Bool = true, includeBody: Bool = true) -> String {
        var log: String = "\n🌎 \(request.methodAndPath)"
        
        if includeHeaders {
            log += request.headers
        }
        
        if includeBody {
            log += request.bodyString
        }
        return log
    }
    
    /// Print a successful request to the console with a print statement or custom breakpoint
    /// - Parameters:
    ///   - data: The JSON response in Data form. If you don't want to log the body of the response, omit this parameter.
    ///   - response: The successful network response
    ///   - includeBody: Whether or not you'd like to include the JSON response in your log.
    /// - Returns: Human readable text for logging in our console.
    static func requestSuccessLog(data: Foundation.Data? = nil, response: URLResponse, includeBody: Bool = true) -> String {
        var log: String = "\n✅ " + response.statusAndPath
        
        if includeBody, let jsonText = data?.asJSONText {
            log += "\n\(jsonText)"
        }
        return log + "\n"
    }
    
    /// Print a failed request to the console with a print statement or custom breakpoint
    static func requestFailureLog(error: Error, response: URLResponse?) -> String {
        if error is CancellationError {
            return "⭕️ Network request CANCELLED"
        }
        var message = "\n🟥 "

        if let statusAndPath = response?.statusAndPath, !statusAndPath.isEmpty {
            message += "\(statusAndPath)\n    "
        }
        return message
            + error.localizedDescription
            + "\n"
    }
}

// MARK: - Helper Extensions

private extension URLRequest {
    
    /// You can use this to print out the cURL of a network request to the console.
    var cURL: String {
        "cURL " + methodAndPath + headers + bodyString
    }
    
    var methodAndPath: String {
        let method = "-X \"\(self.httpMethod ?? "GET")\" "
        let url: String = "\"\(self.url?.absoluteString ?? "")\" \n"
        return method + url
    }
    
    var headers: String {
        var headers = ""
        
        if let httpHeaders = self.allHTTPHeaderFields, !httpHeaders.keys.isEmpty {
            for (key, value) in httpHeaders {
                headers += "-H '\(key): \(value)'\\ \n"
            }
        }
        return headers
    }
    
    var bodyString: String {
        guard let text = self.httpBody?.asJSONText else {
            return ""
        }
        return "-d $'\(text)'"
    }
}

private extension URLResponse {
    
    var statusAndPath: String {
        var text = ""
        
        if let statusCode = (self as? HTTPURLResponse)?.statusCode {
            text += " (\(statusCode))"
        }
        
        if let path = self.url?.absoluteString {
            text += " \(path)"
        }
        return text
    }
}

private extension Foundation.Data {
    
    /// You can use this to print out the raw data response of a network request in the console.
    ///
    /// In order to get a string that prints nicely in the console, we take a `Data` object, convert it to a JSON dictionary,
    /// and then convert it back to `Data` to generate our String.
    var asJSONText: String? {
        if let jsonString = self.asJSON?.jsonString {
            return jsonString.isEmpty ? nil : jsonString
            
        } else if let jsonArray = self.asJSONArray {
            let arrayString = jsonArray.reduce("") { result, json -> String in
                let addition = json.jsonString

                if result.isEmpty {
                    return addition
                } else {
                    return result + ",\n" + addition
                }
            }
            return arrayString.isEmpty ? nil : "{\n\(arrayString)\n}"
            
        } else {
            return nil
        }
    }
    
    var asJSON: [String: Any]? {
        jsonSerialized as? [String: Any]
    }
    
    var asJSONArray: [[String: Any]]? {
        jsonSerialized as? [[String: Any]]
    }
    
    var jsonSerialized: Any? {
        try? JSONSerialization.jsonObject(with: self, options: .allowFragments)
    }
}

private extension Dictionary where Key == String, Value == Any {
    
    var jsonString: String {
        do {
            let data = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? ""
        } catch _ {
            return ""
        }
    }
}

#endif
