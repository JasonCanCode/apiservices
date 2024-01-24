import Foundation
@testable import APIServices
import XCTest

final class MockingTests: XCTestCase {
    
    override func setUpWithError() throws {
        URLSession.useMockData = true
        
        try MockURLProtocol.configure(root: "MockJSON", bundle: .module)
    }
    
    override class func tearDown() {
        URLSession.useMockData = false
    }
    
    func test_autoregister() async throws {
        let firstResponse = try await loadData()
        XCTAssertEqual(firstResponse, "Data1")
        
        let secondResponse = try await loadData()
        XCTAssertEqual(secondResponse, "Data2")
        
        let thirdResponse = try await loadData()
        XCTAssertEqual(thirdResponse, "Data3")
        
        let fourthResponse = try await loadData()
        XCTAssertEqual(fourthResponse, "Data1")
        
        let otherResponse = try await loadData(method: "GetData2")
        XCTAssertEqual(otherResponse, "Data2")
        
        let otherOtherResponse = try await loadData(method: "GetData3")
        XCTAssertEqual(otherOtherResponse, "Data")
    }
    
    func test_directory_sequence() async throws {
        MockURLProtocol.responseLoaders = [
            Endpoint(service: "Test", method: "GetData"): FileResponseLoader(
                directory: "MockJSON/TestSequence",
                bundle: .module
            )
        ]
        
        let firstResponse = try await loadData()
        XCTAssertEqual(firstResponse, "Data11")
        
        let secondResponse = try await loadData()
        XCTAssertEqual(secondResponse, "Data22")
        
        let thirdResponse = try await loadData()
        XCTAssertEqual(thirdResponse, "Data33")
        
        let fourthResponse = try await loadData()
        XCTAssertEqual(fourthResponse, "Data11")
    }
    
    func test_file_list_sequence() async throws {
        MockURLProtocol.responseLoaders = [
            Endpoint(service: "Test", method: "GetData"): FileResponseLoader(
                files: [
                    "MockJSON/TestSequence/GetData-22",
                    "MockJSON/TestSequence/GetData-11",
                    "MockJSON/TestSequence/GetData-11",
                    "MockJSON/TestSequence/GetData-33"
                ],
                bundle: .module
            )
        ]
        
        let firstResponse = try await loadData()
        XCTAssertEqual(firstResponse, "Data22")
        
        let secondResponse = try await loadData()
        XCTAssertEqual(secondResponse, "Data11")
        
        let thirdResponse = try await loadData()
        XCTAssertEqual(thirdResponse, "Data11")
        
        let fourthResponse = try await loadData()
        XCTAssertEqual(fourthResponse, "Data33")
        
        let fifthResponse = try await loadData()
        XCTAssertEqual(fifthResponse, "Data22")
    }
    
    func test_single_file() async throws {
        MockURLProtocol.responseLoaders = [
            Endpoint(service: "Test", method: "GetData"): FileResponseLoader(
                "MockJSON/TestSequence/GetData-33",
                bundle: .module
            )
        ]
        
        let firstResponse = try await loadData()
        XCTAssertEqual(firstResponse, "Data33")
        
        let secondResponse = try await loadData()
        XCTAssertEqual(secondResponse, "Data33")
    }
    
    private func loadData(method: String = "GetData") async throws -> String {
        struct Response: Decodable {
            let data: String
        }
        
        let url = URL(string: "https://www.test.com/service/Test/\(method)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.data
    }
}
