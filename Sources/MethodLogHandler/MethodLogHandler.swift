//
// Created by Bas van der Hoek on 08/02/2021.
// Copyright (c) 2021 Bas van der Hoek. All rights reserved.
//

import Darwin
import Foundation
import Logging

public struct MethodLogHandler: LogHandler {

  public static func standardOutput(label: String) -> MethodLogHandler {
    MethodLogHandler(label: label, stream: StdioOutputStream.stdout)
  }

  public static func standardError(label: String) -> MethodLogHandler {
    MethodLogHandler(label: label, stream: StdioOutputStream.stderr)
  }

  private let stream: TextOutputStream
  private let label: String

  public var logLevel: Logger.Level = .info

  private var prettyMetadata: String?
  public var metadata = Logger.Metadata() {
    didSet {
      self.prettyMetadata = self.prettify(metadata)
    }
  }

  public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
    get {
      metadata[metadataKey]
    }
    set {
      metadata[metadataKey] = newValue
    }
  }

  // internal for testing only
  internal init(label: String, stream: TextOutputStream) {
    self.label = label
    self.stream = stream
  }

  public func log(level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt) {
    var stream = stream
    let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
    stream.write("\(timestamp()) \(level) \(filename).\(function.split(separator: "(").first!) \(message)\n")
  }

  private func prettify(_ metadata: Logger.Metadata) -> String? {
    !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
  }

  private func timestamp() -> String {
    var buffer = [Int8](repeating: 0, count: 255)
    var timestamp = time(nil)
    let localTime = localtime(&timestamp)
    strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
    return buffer.withUnsafeBufferPointer {
      $0.withMemoryRebound(to: CChar.self) {
        String(cString: $0.baseAddress!)
      }
    }
  }
}

let systemStderr = Darwin.stderr
let systemStdout = Darwin.stdout

internal struct StdioOutputStream: TextOutputStream {
  internal let file: UnsafeMutablePointer<FILE>
  internal let flushMode: FlushMode

  internal func write(_ string: String) {
    string.withCString { ptr in
      #if os(Windows)
      _lock_file(file)
      #else
      flockfile(file)
      #endif
      defer {
        #if os(Windows)
        _unlock_file(file)
        #else
        funlockfile(file)
        #endif
      }
      _ = fputs(ptr, file)
      if case .always = flushMode {
        flush()
      }
    }
  }

  /// Flush the underlying stream.
  /// This has no effect when using the `.always` flush mode, which is the default
  internal func flush() {
    _ = fflush(file)
  }

  internal static let stderr = StdioOutputStream(file: systemStderr, flushMode: .always)
  internal static let stdout = StdioOutputStream(file: systemStdout, flushMode: .always)

  /// Defines the flushing strategy for the underlying stream.
  internal enum FlushMode {
    case undefined
    case always
  }
}
