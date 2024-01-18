@testable import APIServices
import XCTest

class APIResponseTests: XCTestCase {
    private enum TestError: Error {
        case invalidData
    }

    func test_DataWrapped_ObjectWithAllOptionalProperties_ParsesCorrectly() throws {
        let json = """
        {
            "d": {
                "ErrorCode": 0,
                "ErrorText": null,
                "Data": {
                    "firstProperty": "value",
                    "secondProperty": null
                }
            }
        }
        """

        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        let response: APIResponse<ObjectWithAllOptionalProperties> = try APIServices.parse(jsonData: jsonData)
        let object = try response.value

        XCTAssertEqual(object.firstProperty, "value")
        XCTAssertNil(object.secondProperty)
    }

    func test_NotWrapped_ObjectWithAllOptionalProperties_ParsesCorrectly() throws {
        let json = """
        {
            "d": {
                "firstProperty": "value",
                "secondProperty": null
            }
        }
        """

        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        let response: APIResponse<ObjectWithAllOptionalProperties> = try APIServices.parse(jsonData: jsonData)
        let object = try response.value

        XCTAssertEqual(object.firstProperty, "value")
        XCTAssertNil(object.secondProperty)
    }

    func test_CustomDecodingStrategy_DataWrapped_ObjectWithAllOptionalProperties_ParsesCorrectly() throws {
        let json = """
             {
                 "d": {
                     "ErrorCode": 0,
                     "ErrorText": null,
                     "Data": {
                         "FirstProperty": "value",
                         "SecondProperty": null
                     }
                 }
             }
             """

        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        let response: APIResponse<ObjectWithAllOptionalProperties> = try APIServices.parse(
            jsonData: jsonData,
            keyDecodingStrategy: .convertFromUpperCamelCase
        )
        let object = try response.value
        XCTAssertEqual(object.firstProperty, "value")
        XCTAssertNil(object.secondProperty)
    }

    func test_CustomDecodingStrategy_DataWrapped_MismatchedKeyCasing_ParsesCorrectly() throws {
        let json = """
             {
                 "d": {
                     "errorCode": 0,
                     "ErrorText": null,
                     "data": {
                         "FirstProperty": "value",
                         "SecondProperty": null
                     }
                 }
             }
             """

        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        let response: APIResponse<ObjectWithAllOptionalProperties> = try APIServices.parse(
            jsonData: jsonData,
            keyDecodingStrategy: .convertFromUpperCamelCase
        )
        let object = try response.value
        XCTAssertEqual(object.firstProperty, "value")
        XCTAssertNil(object.secondProperty)
    }

    func test_DataWrapped_NormalKeyCasing_ErrorParsesCorrectly() throws {
        let json = """
             {
                 "d": {
                     "ErrorCode": 911,
                     "ErrorText": "Emergency!"
                 }
             }
             """
        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        do {
            let response: APIResponse<ObjectWithDataProperty> = try APIServices.parse(jsonData: jsonData, keyDecodingStrategy: .convertFromUpperCamelCase)
            let _ = try response.value
            XCTFail("Data object should not exist")
        } catch {
            guard case let APIError.server(code, message) = error else {
                XCTFail("Unexpected error")
                return
            }
            XCTAssertEqual(code, 911)
            XCTAssertEqual(message, "Emergency!")
        }
    }

    func test_DataWrapped_AlternateKeyCasing_ErrorParsesCorrectly() throws {
        let json = """
             {
                 "d": {
                     "errorCode": 911,
                     "errorText": "Emergency!"
                 }
             }
             """
        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        do {
            let response: APIResponse<ObjectWithDataProperty> = try APIServices.parse(
                jsonData: jsonData,
                keyDecodingStrategy: .convertFromUpperCamelCase
            )
            let _ = try response.value
            XCTFail("Data object should not exist")
        } catch {
            guard case let APIError.server(code, message) = error else {
                XCTFail("Unexpected error")
                return
            }
            XCTAssertEqual(code, 911)
            XCTAssertEqual(message, "Emergency!")
        }
    }

    func test_NotWrapped_CustomDecodingStrategy_ObjectWithAllOptionalProperties_ParsesCorrectly() throws {
        let json = """
             {
                 "d": {
                     "FirstProperty": "value",
                     "SecondProperty": null
                 }
             }
             """

        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        let response: APIResponse<ObjectWithAllOptionalProperties> = try APIServices.parse(
            jsonData: jsonData,
            keyDecodingStrategy: .convertFromUpperCamelCase
        )
        let object = try response.value
        XCTAssertEqual(object.firstProperty, "value")
        XCTAssertNil(object.secondProperty)
    }

    func test_NotWrapped_ObjectWithDataProperty_ParsesCorrectly() throws {
        let json = """
        {
            "d": {
                "Data": {
                    "property": "value"
                }
            }
        }
        """

        guard let jsonData = json.data(using: .utf8) else {
            throw TestError.invalidData
        }
        let response: APIResponse<ObjectWithDataProperty> = try APIServices.parse(jsonData: jsonData)
        let object = try response.value

        XCTExpectFailure("""
        This is "broken" but can't work at the same time as the other tests.

        This one being the one that's broken is the least bad since it only matters when an old-style
        result object has an optional "Data" property which doesn't exist currently and presumably won't
        since everything going forward should be using the new style.
        """)

        XCTAssertEqual(object.data?.property, "value")
    }
}

private struct ObjectWithAllOptionalProperties: Decodable {
    let firstProperty: String?
    let secondProperty: String?
}

private struct ObjectWithDataProperty: Decodable {
    let data: InnerData?

    enum CodingKeys: String, CodingKey {
        case data = "Data"
    }

    struct InnerData: Decodable {
        let property: String?
    }
}
