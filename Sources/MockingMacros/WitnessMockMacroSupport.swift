//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax

/// Lowers a struct-witness stored property into the controller `$` peer and the `init(mock:)` wiring.
/// Closure-typed properties become `Mock.Method` invocations; value properties become `Mock.Property.Get`.
enum WitnessMockMacroSupport {
    struct Property {
        let name: String
        let peerDeclaration: String
        let wiringExpression: String
    }

    static func property(
        name: String,
        type: TypeSyntax,
        defaultValue: String?,
        access: String,
        genericParameters: Set<String> = []
    ) throws -> Property {
        if let function = MacroSyntaxSupport.functionType(from: type) {
            return try closureProperty(name: name, function: function, access: access)
        }
        return valueProperty(
            name: name,
            type: type,
            defaultValue: defaultValue,
            access: access,
            genericParameters: genericParameters
        )
    }

    private static func closureProperty(
        name: String,
        function: FunctionTypeSyntax,
        access: String
    ) throws -> Property {
        let params = function.parameters
        for param in params where isInout(param) || param.ellipsis != nil {
            throw MockableMacroError.unsupportedClosureParameter
        }

        let isAsync = function.effectSpecifiers?.asyncSpecifier != nil
        let failure = closureFailure(function)
        let output = MacroSyntaxSupport.mockTypeName(from: function.returnClause.type)
        let inputs = inputsType(params)
        let subject = "\(name)(\(subjectLabels(params)))"

        let factory = MacroSyntaxSupport.invocationFactory(
            inputs: inputs,
            output: output,
            isAsync: isAsync,
            failure: failure,
            subject: subject
        )
        let peer = "\(access)nonisolated let \(MacroSyntaxSupport.mockPeerName(for: name)) = \(factory)"

        return Property(
            name: name,
            peerDeclaration: peer,
            wiringExpression: closureWiring(
                name: name,
                params: params,
                isAsync: isAsync,
                failure: failure
            )
        )
    }

    private static func valueProperty(
        name: String,
        type: TypeSyntax,
        defaultValue: String?,
        access: String,
        genericParameters: Set<String>
    ) -> Property {
        let valueType = MacroSyntaxSupport.mockTypeName(from: type)
        let peer = "\(access)nonisolated let \(MacroSyntaxSupport.mockPeerName(for: name)) = "
            + "\(MacroSyntaxSupport.runtimeNamespace)Mock.Property<\(valueType)>.Get(subject: \"\(name)\")"
        let peerName = MacroSyntaxSupport.mockPeerName(for: name)

        // A generic-typed value with no declared default can't fall back to `.mock` (its type may not be
        // `Mockable`), so wire it through the runtime-lenient `result()` path instead of a compile-time `??`.
        let wiring: String
        if defaultValue == nil, MacroSyntaxSupport.mentionsGenericParameter(type, genericParameters) {
            wiring = "\(name): mock.\(peerName).get.result()"
        } else {
            wiring = "\(name): mock.\(peerName).get.returns ?? \(defaultValue ?? ".mock")"
        }
        return Property(name: name, peerDeclaration: peer, wiringExpression: wiring)
    }

    private static func closureFailure(_ function: FunctionTypeSyntax) -> String? {
        guard let throwsClause = function.effectSpecifiers?.throwsClause else { return nil }
        if let type = throwsClause.type {
            return MacroSyntaxSupport.failureTypeName(from: type)
        }
        return MacroSyntaxSupport.anyError
    }

    private static func inputsType(_ params: TupleTypeElementListSyntax) -> String {
        let elements = Array(params)
        guard !elements.isEmpty else { return "Void" }
        if elements.count == 1 {
            return MacroSyntaxSupport.functionInputTypeName(from: elements[0].type)
        }
        let fields = elements.enumerated().map { index, element in
            "\(label(for: element, index: index)): \(MacroSyntaxSupport.functionInputTypeName(from: element.type))"
        }
        return "(\(fields.joined(separator: ", ")))"
    }

    private static func closureWiring(
        name: String,
        params: TupleTypeElementListSyntax,
        isAsync: Bool,
        failure: String?
    ) -> String {
        let peer = MacroSyntaxSupport.mockPeerName(for: name)
        let elements = Array(params)
        let variables = elements.enumerated().map { index, element in variableName(for: element, index: index) }

        let callArgs: String
        switch elements.count {
        case 0:
            callArgs = "()"
        case 1:
            callArgs = "(\(variables[0]))"
        default:
            let fields = elements.enumerated().map { index, element in
                "\(label(for: element, index: index)): \(variables[index])"
            }
            callArgs = "((\(fields.joined(separator: ", "))))"
        }

        let effects = "\(failure != nil ? "try " : "")\(isAsync ? "await " : "")"
        let body = "\(effects)mock.\(peer).result\(callArgs)"

        // A typed `throws(E)` property needs an explicit closure signature: Swift infers an unannotated
        // closure literal as `throws(any Error)`, which cannot convert to the declared failure type.
        if let signature = typedThrowsSignature(
            params: elements,
            variables: variables,
            isAsync: isAsync,
            failure: failure
        ) {
            return "\(name): { \(signature) in \(body) }"
        }

        let capture = variables.isEmpty ? "" : "\(variables.joined(separator: ", ")) in "
        return "\(name): { \(capture)\(body) }"
    }

    /// Explicit closure signature for a typed-throws property, or `nil` when plain inference is enough.
    /// Untyped `throws` and non-throwing closures keep the terser inferred form.
    private static func typedThrowsSignature(
        params: [TupleTypeElementSyntax],
        variables: [String],
        isAsync: Bool,
        failure: String?
    ) -> String? {
        guard let failure, failure != MacroSyntaxSupport.anyError else { return nil }
        let declaredParams = params.enumerated().map { index, element in
            "\(variables[index]): \(MacroSyntaxSupport.typeName(from: element.type))"
        }
        // The result type stays inferred: the memberwise-init parameter supplies it, and spelling it here
        // would have to reproduce every declared spelling exactly.
        return "(\(declaredParams.joined(separator: ", ")))\(isAsync ? " async" : "") throws(\(failure))"
    }

    private static func isInout(_ element: TupleTypeElementSyntax) -> Bool {
        if element.inoutKeyword != nil { return true }
        if let attributed = element.type.as(AttributedTypeSyntax.self) {
            return attributed.specifiers.contains { $0.trimmedDescription == "inout" }
        }
        return false
    }

    /// External call label used in the subject and labeled input tuple; `_` when the parameter is unnamed.
    private static func label(for element: TupleTypeElementSyntax, index: Int) -> String {
        if let second = element.secondName?.text, second != "_" { return second }
        if let first = element.firstName?.text, first != "_" { return first }
        return "arg\(index)"
    }

    private static func subjectLabels(_ params: TupleTypeElementListSyntax) -> String {
        params.map { element in
            if let second = element.secondName?.text, second != "_" { return "\(second):" }
            if let first = element.firstName?.text, first != "_" { return "\(first):" }
            return "_:"
        }.joined()
    }

    /// Closure-literal parameter name; falls back to positional `argN` for unnamed parameters.
    private static func variableName(for element: TupleTypeElementSyntax, index: Int) -> String {
        if let second = element.secondName?.text, second != "_" { return second }
        if let first = element.firstName?.text, first != "_" { return first }
        return "arg\(index)"
    }
}
