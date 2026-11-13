//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if DEBUG || MOCKING
#if Dependencies
// swift-dependencies re-exports IssueReporting, under whichever package name its manifest uses.
import Dependencies
#endif

enum MockSupport {
    static func mock<Output>(for type: Output.Type) -> Output? {
        // `Void` cannot conform to `Mockable`, because it is a tuple type.
        // Its only value is the correct lenient default, so supply it here.
        if Output.self == Void.self { return () as? Output }
        guard let mockable = type as? any Mockable.Type else { return nil }
        return mockable.mock(as: Output.self) as? Output
    }

    /// An unset call. The `Dependencies` trait reports a test issue and continues where a value exists.
    static func unconfigured<Output, Failure: Error>(
        _ subject: String?,
        failing: Failure.Type,
        file: StaticString,
        line: UInt
    ) throws(Failure) -> Output {
        let message = "Unconfigured mock call\(subject.map { " to '\($0)'" } ?? "")."
        #if Dependencies
        // Swift 6 reads `#file` as `#fileID`. Swift Testing needs a column of 1 or more.
        reportIssue(message, fileID: file, filePath: file, line: line, column: 1)
        if let value = mock(for: Output.self) { return value }
        if let error = UnconfiguredCall(message: message) as? Failure ?? mock(for: Failure.self) { throw error }
        #endif
        fatalError(message, file: file, line: line)
    }
}

/// What an unset call throws when its error type is untyped.
public struct UnconfiguredCall: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}
#endif
