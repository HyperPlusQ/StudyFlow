import XCTest
@testable import StudyFlowKit

final class SubmissionMethodResolverTests: XCTestCase {
    func testHTTPURLTarget() throws {
        let target = try XCTUnwrap(SubmissionMethodResolver.target(for: "https://example.com/path"))
        guard case let .url(url) = target else {
            return XCTFail("Expected URL target")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/path")
    }

    func testWWWURLGetsHTTPSScheme() throws {
        let target = try XCTUnwrap(SubmissionMethodResolver.target(for: "www.example.com"))
        guard case let .url(url) = target else {
            return XCTFail("Expected URL target")
        }
        XCTAssertEqual(url.absoluteString, "https://www.example.com")
    }

    func testMailtoTarget() throws {
        let target = try XCTUnwrap(SubmissionMethodResolver.target(for: "mailto:user@example.com"))
        guard case let .email(address) = target else {
            return XCTFail("Expected email target")
        }
        XCTAssertEqual(address, "user@example.com")
    }

    func testPlainEmailTarget() throws {
        let target = try XCTUnwrap(SubmissionMethodResolver.target(for: "  user@example.com  "))
        guard case let .email(address) = target else {
            return XCTFail("Expected email target")
        }
        XCTAssertEqual(address, "user@example.com")
    }

    func testInvalidTextReturnsNil() {
        XCTAssertNil(SubmissionMethodResolver.target(for: "请查看作业说明"))
    }
}
