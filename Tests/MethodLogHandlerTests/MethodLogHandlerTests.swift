import XCTest
import Logging

@testable import MethodLogHandler

var log = Logger(label: "com.hoek")

final class MethodLogHandlerTests: XCTestCase {

  func test_logging() throws {
    LoggingSystem.bootstrap(MethodLogHandler.standardOutput)
    log.info("Hello, world")
  }

}
