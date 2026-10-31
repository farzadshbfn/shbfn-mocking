//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import Testing

struct `Mockable Macro Struct` {
    // A value-only struct generates the same controller grammar as a witness — value properties become
    // configure-only `Mock.Property.Get` peers, and `.mock` stays a lenient fixture (`Int.mock`, `String.mock`).
    @Test func structGeneratesControllerAndLenientMock() {
        assertMacro {
            """
            @Mockable
            struct SampleConfig {
                var timeout: Int
                var label: String
            }
            """
        } expansion: {
            """
            struct SampleConfig {
                var timeout: Int
                var label: String
            }

            extension SampleConfig: Mockable {
                #if DEBUG || MOCKING
                final class Mock: Sendable, MockWithable {
                    nonisolated let $timeout = Mocking.Mock.Property<Int>.Get(subject: "timeout")

                    nonisolated let $label = Mocking.Mock.Property<String>.Get(subject: "label")

                    init() {
                    }

                    var instance: SampleConfig {
                        SampleConfig(mock: self)
                    }
                }

                static var mock: SampleConfig {
                    Mock().instance
                }

                init(mock: Mock) {
                    self.init(
                        timeout: mock.$timeout.get.returns ?? .mock,
                        label: mock.$label.get.returns ?? .mock
                    )
                }
                #endif
            }
            """
        }
    }
}
#endif
