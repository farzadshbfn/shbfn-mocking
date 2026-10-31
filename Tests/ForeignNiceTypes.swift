//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import Mocking

struct WidgetID: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

#if DEBUG || MOCKING
extension WidgetID: Mockable {
    static var mock: WidgetID { WidgetID("fixture-default-id") }
}

struct Widget: Sendable, Equatable {
    let id: WidgetID
    let score: Int
}

extension Widget: Mockable {
    static var mock: Widget { Widget(id: .mock, score: 42) }
}
#endif

struct StrictWidget: Sendable, Equatable {
    let id: WidgetID
}

extension StrictWidget: Mockable {
    #if DEBUG || MOCKING
    static var mock: StrictWidget { StrictWidget(id: WidgetID("strict-default")) }
    #endif
}

struct PlainWidget: Sendable, Equatable {
    let id: WidgetID
}
