//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@_spi(PluginMessage) import SwiftCompilerPluginMessageHandling
import XCTest

final class JSONTests: XCTestCase {

  func testEmptyStruct() {
    let value = EmptyStruct()
    _testRoundTrip(of: value, expectedJSON: "{}")
  }

  func testEmptyClass() {
    let value = EmptyClass()
    _testRoundTrip(of: value, expectedJSON: "{}")
  }

  func testTrivialEnumDefault() {
    _testRoundTrip(of: Direction.left, expectedJSON: #"{"left":{}}"#)
    _testRoundTrip(of: Direction.right, expectedJSON: #"{"right":{}}"#)
  }

  func testTrivialEnumRawValue() {
    _testRoundTrip(of: Animal.dog, expectedJSON: #""dog""#)
    _testRoundTrip(of: Animal.cat, expectedJSON: #""cat""#)
  }

  func testTrivialEnumCustom() {
    _testRoundTrip(of: Switch.off, expectedJSON: "false")
    _testRoundTrip(of: Switch.on, expectedJSON: "true")
  }

  func testEnumWithAssociated() {
    let tree: Tree = .dictionary([
      "name": .string("John Doe"),
      "data": .array([.int(12), .string("foo")]),
    ])
    _testRoundTrip(
      of: tree,
      expectedJSON: #"""
        {"dictionary":{"_0":{"data":{"array":{"_0":[{"int":{"_0":12}},{"string":{"_0":"foo"}}]}},"name":{"string":{"_0":"John Doe"}}}}}
        """#
    )
  }

  func testArrayOfInt() {
    let arr: [Int] = [12, 42]
    _testRoundTrip(of: arr, expectedJSON: "[12,42]")
    let empty: [Int] = []
    _testRoundTrip(of: empty, expectedJSON: "[]")
  }

  func testComplexStruct() {
    let empty = ComplexStruct(result: nil, diagnostics: [])
    _testRoundTrip(of: empty, expectedJSON: #"{"diagnostics":[]}"#)

    let value = ComplexStruct(
      result: "\tresult\nfoo",
      diagnostics: [
        .init(
          message: "error 🛑",
          animal: .cat,
          data: [nil, 42]
        )
      ]
    )
    _testRoundTrip(
      of: value,
      expectedJSON: #"""
        {"diagnostics":[{"animal":"cat","data":[null,42],"message":"error 🛑"}],"result":"\tresult\nfoo"}
        """#
    )
  }

  func testUnicodeEscape() {
    _testRoundTrip(
      of: "\n\u{A9}\u{0}\u{07}\u{1B}",
      expectedJSON: #"""
        "\n©\u0000\u0007\u001B"
        """#
    )
  }

  func testTypeCoercion() {
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)
  }

  private func _testRoundTrip<T: Codable & Equatable>(of value: T, expectedJSON: String? = nil) {
    let payload: [UInt8]
    do {
      payload = try JSON.encode(value)
    } catch let error {
      XCTFail("Failed to encode \(T.self) to JSON: \(error)")
      return
    }

    if let expectedJSON {
      let jsonStr = String(decoding: payload, as: UTF8.self)
      XCTAssertEqual(jsonStr, expectedJSON)
    }

    let decoded: T
    do {
      decoded = try payload.withUnsafeBufferPointer {
        try JSON.decode(T.self, from: $0)
      }
    } catch let error {
      XCTFail("Failed to decode \(T.self) from JSON: \(error)")
      return
    }
    XCTAssertEqual(value, decoded)
  }

  private func _testRoundTripTypeCoercionFailure<T, U>(of value: T, as type: U.Type) where T: Codable, U: Codable {
    do {
      let data = try JSONEncoder().encode(value)
      let _ = try JSONDecoder().decode(U.self, from: data)
      XCTFail("Coercion from \(T.self) to \(U.self) was expected to fail.")
    } catch {}
  }
}

// MARK: - Test Types

fileprivate struct EmptyStruct: Codable, Equatable {
  static func == (_ lhs: EmptyStruct, _ rhs: EmptyStruct) -> Bool {
    return true
  }
}

fileprivate class EmptyClass: Codable, Equatable {
  static func == (_ lhs: EmptyClass, _ rhs: EmptyClass) -> Bool {
    return true
  }
}

fileprivate enum Direction: Codable {
  case right
  case left
}

fileprivate enum Animal: String, Codable {
  case dog
  case cat
}

fileprivate enum Switch: Codable {
  case off
  case on

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    switch try container.decode(Bool.self) {
    case false: self = .off
    case true: self = .on
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .off: try container.encode(false)
    case .on: try container.encode(true)
    }
  }
}

fileprivate enum Tree: Codable, Equatable {
  indirect case int(Int)
  indirect case string(String)
  indirect case array([Self])
  indirect case dictionary([String: Self])
}

fileprivate struct ComplexStruct: Codable, Equatable {
  struct Diagnostic: Codable, Equatable {
    var message: String
    var animal: Animal
    var data: [Int?]
  }

  var result: String?
  var diagnostics: [Diagnostic]
}
