import Foundation

/// Represents the path to an API endpoint
struct Endpoint: Hashable {
    
    /// Service the endpoint is in, e.g. "Users"
    let service: String
    
    /// Name of the endpoint method, e.g. "GetDetails"
    let method: String
    
    init(service: String, method: String) {
        self.service = service
        self.method = method
    }
}

extension URL {
    /// The endpoint that this url is pointing to
    var endpoint: Endpoint {
        let method = lastPathComponent
        let service = deletingLastPathComponent().lastPathComponent
        
        return Endpoint(service: service, method: method)
    }
}
