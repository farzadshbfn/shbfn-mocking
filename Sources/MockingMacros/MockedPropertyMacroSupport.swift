//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax

enum MockedPropertyMacroSupport {
    static func propertyFactory(for kind: ParsedMockedPropertyKind, valueType: String, subject: String) -> String {
        let subjectArg = "subject: \"\(subject)\""
        let base = "\(MacroSyntaxSupport.runtimeNamespace)Mock.Property<\(valueType)>"
        switch kind {
        case .get:
            return "\(base).Get(\(subjectArg))"
        case .getSet:
            return "\(base).GetSet(\(subjectArg))"
        case .getAsync:
            return "\(base).GetAsync(\(subjectArg))"
        case .getAsyncSet:
            return "\(base).GetAsyncSet(\(subjectArg))"
        case let .getThrows(failure):
            return "\(base).GetThrows<\(failure ?? MacroSyntaxSupport.anyError)>(\(subjectArg))"
        case let .getThrowsSet(failure):
            return "\(base).GetThrowsSet<\(failure ?? MacroSyntaxSupport.anyError)>(\(subjectArg))"
        }
    }

    static func propertyGetCall(for kind: ParsedMockedPropertyKind, peerName: String) -> String {
        let call = "\(peerName).get.result()"
        switch kind {
        case .get, .getSet:
            return call
        case .getAsync, .getAsyncSet:
            return "await \(call)"
        case .getThrows, .getThrowsSet:
            return "try \(call)"
        }
    }

    /// Swift forbids `set` on properties whose getter is `async` or `throws`.
    static func propertyEmitsSetAccessor(for kind: ParsedMockedPropertyKind) -> Bool {
        if case .getSet = kind { return true }
        return false
    }

    static func getterAccessorKeyword(for kind: ParsedMockedPropertyKind) -> String {
        switch kind {
        case .get, .getSet:
            return "get"
        case .getAsync, .getAsyncSet:
            return "get async"
        case let .getThrows(failure), let .getThrowsSet(failure):
            if let failure {
                return "get throws(\(failure))"
            }
            return "get throws"
        }
    }

    static func mockedPropertyAttribute(for kind: ParsedMockedPropertyKind) -> String {
        switch kind {
        case .getSet:
            return "@MockedProperty"
        case .get:
            return "@MockedProperty(.get)"
        case .getAsync:
            return "@MockedProperty(.getAsync)"
        case .getAsyncSet:
            return "@MockedProperty(.getAsyncSet)"
        case .getThrows(nil):
            return "@MockedProperty(.getThrows)"
        case let .getThrows(failure?):
            return "@MockedProperty(.getThrows(\(failure).self))"
        case .getThrowsSet(nil):
            return "@MockedProperty(.getThrowsSet)"
        case let .getThrowsSet(failure?):
            return "@MockedProperty(.getThrowsSet(\(failure).self))"
        }
    }

    static func inferredPropertyKind(
        for property: VariableDeclSyntax,
        binding: PatternBindingSyntax
    ) -> ParsedMockedPropertyKind {
        if let accessors = binding.accessorBlock?.accessors, case let .accessors(list) = accessors {
            let traits = PropertyAccessorTraits(property: property, binding: binding)
            let getter = list.first { $0.accessorSpecifier.text == "get" }
            let isAsync = getter?.effectSpecifiers?.asyncSpecifier != nil
            let throwsClause = getter?.effectSpecifiers?.throwsClause
            let typedFailure = throwsClause?.type.map { MacroSyntaxSupport.failureTypeName(from: $0) }

            if traits.hasSetter {
                if isAsync { return .getAsyncSet }
                if let typedFailure { return .getThrowsSet(failure: typedFailure) }
                if throwsClause != nil { return .getThrowsSet(failure: nil) }
                return .getSet
            }
            if isAsync { return .getAsync }
            if let typedFailure { return .getThrows(failure: typedFailure) }
            if throwsClause != nil { return .getThrows(failure: nil) }
            return .get
        }
        return defaultMockedPropertyKind(for: property, binding: binding)
    }

    static func parseMockedPropertyKind(
        from attribute: AttributeSyntax,
        property: VariableDeclSyntax,
        binding: PatternBindingSyntax
    ) throws -> ParsedMockedPropertyKind {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let expression = arguments.first?.expression else {
            return defaultMockedPropertyKind(for: property, binding: binding)
        }
        return try parseMockedPropertyKindExpression(expression)
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func parseMockedPropertyKindExpression(_ expression: ExprSyntax) throws -> ParsedMockedPropertyKind {
        if let functionCall = expression.as(FunctionCallExprSyntax.self),
           let member = functionCall.calledExpression.as(MemberAccessExprSyntax.self) {
            let failure = functionCall.arguments.first.map { typeNameFromMetatype($0.expression) }
            switch member.declName.baseName.text {
            case "getThrows":
                guard let failure else { throw MockedPropertyKindError.missingFailureType("getThrows") }
                return .getThrows(failure: failure)
            case "getThrowsSet":
                guard let failure else { throw MockedPropertyKindError.missingFailureType("getThrowsSet") }
                return .getThrowsSet(failure: failure)
            default:
                break
            }
        }

        if let member = expression.as(MemberAccessExprSyntax.self) {
            switch member.declName.baseName.text {
            case "get": return .get
            case "getSet": return .getSet
            case "getAsync": return .getAsync
            case "getAsyncSet": return .getAsyncSet
            case "getThrows": return .getThrows(failure: nil)
            case "getThrowsSet": return .getThrowsSet(failure: nil)
            default:
                break
            }
        }

        throw MockedPropertyKindError.unrecognizedKind(expression.trimmedDescription)
    }

    static func defaultMockedPropertyKind(
        for property: VariableDeclSyntax,
        binding: PatternBindingSyntax
    ) -> ParsedMockedPropertyKind {
        let traits = PropertyAccessorTraits(property: property, binding: binding)
        if traits.hasSetter {
            return .getSet
        }
        return .get
    }

    static func typeNameFromMetatype(_ expression: ExprSyntax) -> String {
        if let member = expression.as(MemberAccessExprSyntax.self),
           member.declName.baseName.text == "self" {
            return typeNameFromExpr(member.base)
        }
        return expression.trimmedDescription
    }

    static func typeNameFromExpr(_ expression: ExprSyntax?) -> String {
        guard let expression else { return "Unknown" }
        if let identifier = expression.as(DeclReferenceExprSyntax.self) {
            return identifier.baseName.text
        }
        return expression.trimmedDescription
    }
}

enum ParsedMockedPropertyKind {
    case get
    case getSet
    case getAsync
    case getAsyncSet
    case getThrows(failure: String?)
    case getThrowsSet(failure: String?)
}

enum MockedPropertyKindError: Error, CustomStringConvertible {
    case unrecognizedKind(String)
    case missingFailureType(String)

    var description: String {
        switch self {
        case let .unrecognizedKind(kind):
            "Unrecognized @MockedProperty kind '\(kind)'."
        case let .missingFailureType(kind):
            "@MockedProperty(.\(kind)) requires a failure type, e.g. .\(kind)(MyError.self)."
        }
    }
}

private struct PropertyAccessorTraits {
    let hasSetter: Bool

    init(property: VariableDeclSyntax, binding: PatternBindingSyntax) {
        let isLet = property.bindingSpecifier.text == "let"
        let accessorBlock = binding.accessorBlock?.accessors
        switch accessorBlock {
        case let .accessors(list):
            hasSetter = list.contains { $0.accessorSpecifier.text == "set" }
        case .getter, .none:
            hasSetter = binding.accessorBlock == nil && !isLet
        }
    }
}
