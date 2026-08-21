//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax

extension MacroSyntaxSupport {
    static func hasAssociatedTypes(_ protocolDecl: ProtocolDeclSyntax) -> Bool {
        protocolDecl.memberBlock.members.contains { $0.decl.is(AssociatedTypeDeclSyntax.self) }
    }

    /// Spelling for a type used as a protocol/class constraint (inheritance, `where` bounds).
    ///
    /// Bare `Error` means the `Swift.Error` protocol here. A nested `Error` type (repo convention)
    /// must not shadow it — unlike typed `throws(Error)`, which intentionally names the nested type.
    static func constraintTypeName(from type: TypeSyntax) -> String {
        if let identifier = type.as(IdentifierTypeSyntax.self),
           identifier.name.text == "Error",
           identifier.genericArgumentClause == nil {
            return "Swift.Error"
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.map { constraintTypeName(from: $0.type) }.joined(separator: " & ")
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return constraintTypeName(from: attributed.baseType)
        }
        if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
            return "\(someOrAny.someOrAnySpecifier.text) \(constraintTypeName(from: someOrAny.constraint))"
        }
        return type.trimmedDescription
    }

    /// Rewrites `where` requirement text so bare `Error` bounds become `Swift.Error`.
    static func qualifyWhereRequirement(_ requirement: GenericRequirementSyntax) -> String {
        switch requirement.requirement {
        case let .conformanceRequirement(conformance):
            return "\(conformance.leftType.trimmedDescription): \(constraintTypeName(from: conformance.rightType))"
        case let .sameTypeRequirement(sameType):
            return sameType.trimmedDescription
        case let .layoutRequirement(layout):
            return layout.trimmedDescription
        }
    }

    /// Failure type for `Mock.Method` / `Mock.Property` throwing peers.
    ///
    /// - `throws(Error)` keeps bare `Error` — next to a nested `Error` type that is intentional.
    /// - `throws(any Error)` / untyped `throws` become `any Swift.Error` so the nested type cannot shadow.
    static func failureTypeName(from type: TypeSyntax) -> String {
        if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
            let inner = typeName(from: someOrAny.constraint)
            let qualified = inner == "Error" ? "Swift.Error" : inner
            return "\(someOrAny.someOrAnySpecifier.text) \(qualified)"
        }
        return typeName(from: type)
    }

    /// Turns a protocol's associated types into the mock class's generic parameters and `where` clause.
    /// Each `associatedtype` becomes a same-named generic parameter (witnessing the requirement); its
    /// inheritance clause becomes the parameter constraint, and any `where` clauses fold into the class `where`.
    static func associatedTypeGenerics(for protocolDecl: ProtocolDeclSyntax) -> (clause: String, whereClause: String) {
        let associatedTypes = protocolDecl.memberBlock.members.compactMap {
            $0.decl.as(AssociatedTypeDeclSyntax.self)
        }
        guard !associatedTypes.isEmpty else { return ("", "") }

        let params = associatedTypes.map { decl -> String in
            guard let inheritance = decl.inheritanceClause else { return decl.name.text }
            let bounds = inheritance.inheritedTypes.map { constraintTypeName(from: $0.type) }.joined(separator: " & ")
            return "\(decl.name.text): \(bounds)"
        }

        var requirements = associatedTypes.flatMap { decl in
            decl.genericWhereClause?.requirements.map { qualifyWhereRequirement($0) } ?? []
        }
        requirements += protocolDecl.genericWhereClause?.requirements.map { qualifyWhereRequirement($0) } ?? []

        let whereClause = requirements.isEmpty ? "" : " where \(requirements.joined(separator: ", "))"
        return ("<\(params.joined(separator: ", "))>", whereClause)
    }

    /// Method-level generic parameter names (`func send<R: Request>` → `["R"]`).
    /// Stored `$` peers cannot mention these, so types that reference them erase to `Any`.
    static func methodGenericParameters(from node: FunctionDeclSyntax) -> Set<String> {
        Set(node.genericParameterClause?.parameters.map(\.name.text) ?? [])
    }

    /// True when `type`'s spelling mentions any name in `genericParameters` (token scan).
    static func mentionsGenericParameter(_ type: TypeSyntax, _ genericParameters: Set<String>) -> Bool {
        guard !genericParameters.isEmpty else { return false }
        return type.tokens(viewMode: .sourceAccurate).contains { genericParameters.contains($0.text) }
    }

    /// Input type for a `Mock.Method` peer: erase to `Any` when the parameter mentions a method generic.
    static func erasedInputTypeName(from type: TypeSyntax, genericParameters: Set<String>) -> String {
        if mentionsGenericParameter(type, genericParameters) {
            return "Any"
        }
        return functionInputTypeName(from: type)
    }

    /// Failure type for a method peer. Typed throws that mention a method generic erase to `any Swift.Error`.
    static func methodFailureType(from node: FunctionDeclSyntax) -> String? {
        guard isThrowing(node) else { return nil }
        let generics = methodGenericParameters(from: node)
        if let typed = node.signature.effectSpecifiers?.throwsClause?.type {
            if mentionsGenericParameter(typed, generics) {
                return anyError
            }
            return failureTypeName(from: typed)
        }
        return anyError
    }

    /// Typed throws whose failure mentions a method generic need a `do/catch` + `as!` rethrow in the body.
    static func failureNeedsRethrowCast(from node: FunctionDeclSyntax) -> Bool {
        let generics = methodGenericParameters(from: node)
        guard let typed = node.signature.effectSpecifiers?.throwsClause?.type else { return false }
        return mentionsGenericParameter(typed, generics)
    }

    static func methodCallArguments(from node: FunctionDeclSyntax) -> String {
        let generics = methodGenericParameters(from: node)
        let params = node.signature.parameterClause.parameters
        guard !params.isEmpty else { return "" }

        func argumentExpression(for param: FunctionParameterSyntax, index: Int) -> String {
            let variable = functionParameterVariableName(for: param, index: index)
            if mentionsGenericParameter(param.type, generics) {
                return "\(variable) as Any"
            }
            return variable
        }

        if params.count == 1 {
            return argumentExpression(for: params.first!, index: 0)
        }
        let fields = params.enumerated().map { index, param in
            let externalLabel = param.firstName.text
            let expression = argumentExpression(for: param, index: index)
            if externalLabel == "_" {
                return expression
            }
            return "\(externalLabel): \(expression)"
        }.joined(separator: ", ")
        return "(\(fields))"
    }

    /// The `result(…)` call with effects and an output `as!` when the return type was erased.
    static func methodCallExpression(for node: FunctionDeclSyntax, peerName: String) -> String {
        let generics = methodGenericParameters(from: node)
        let args = methodCallArguments(from: node)
        var call: String
        if args.isEmpty {
            call = "\(peerName).result()"
        } else {
            call = "\(peerName).result(\(args))"
        }

        if isAsync(node) {
            if isThrowing(node) {
                call = "try await \(call)"
            } else {
                call = "await \(call)"
            }
        } else if isThrowing(node) {
            call = "try \(call)"
        }

        if let returnType = node.signature.returnClause?.type,
           mentionsGenericParameter(returnType, generics) {
            call = "\(call) as! \(typeName(from: returnType))"
        }
        return call
    }

    /// Full method body: plain `return`, or `do/catch` when typed throws were erased to `any Error`.
    static func methodBodyStatements(for node: FunctionDeclSyntax, peerName: String) -> [CodeBlockItemSyntax] {
        let call = methodCallExpression(for: node, peerName: peerName)
        if failureNeedsRethrowCast(from: node),
           let failureType = node.signature.effectSpecifiers?.throwsClause?.type {
            let rethrow = CodeBlockItemSyntax(stringLiteral: """
                do {
                    return \(call)
                } catch {
                    throw error as! \(typeName(from: failureType))
                }
                """)
            return [rethrow]
        }
        return [CodeBlockItemSyntax(stringLiteral: "return \(call)")]
    }

    static func functionSignature(from node: FunctionDeclSyntax) -> String {
        let genericClause = node.genericParameterClause?.trimmedDescription ?? ""
        let whereClause = node.genericWhereClause.map { " \($0.trimmedDescription)" } ?? ""
        let access = accessModifier(from: node.modifiers)
        let staticKeyword = staticKeyword(node.modifiers)
        let nameAndGenerics = "\(node.name.text)\(genericClause)"
        let signature = node.signature.trimmedDescription
        return "\(access)\(staticKeyword)func \(nameAndGenerics)\(signature)\(whereClause)"
    }
}
