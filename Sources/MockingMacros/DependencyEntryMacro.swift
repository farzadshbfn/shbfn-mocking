//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// Fills a `DependencyValues` property with a `get` and `set` through its key.
/// `any P` reads `P.Key`, which `@MockableDependency` declares. Any other type is its own key.
public struct DependencyEntryMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              property.bindingSpecifier.text == "var",
              property.bindings.count == 1,
              let binding = property.bindings.first,
              binding.accessorBlock == nil,
              binding.initializer == nil,
              let type = binding.typeAnnotation?.type
        else {
            throw DependencyEntryMacroError.notAPlainProperty
        }
        let key = explicitKey(node) ?? inferredKey(from: type)
        return [
            "get { self[\(raw: key).self] }",
            "set { self[\(raw: key).self] = newValue }",
        ]
    }

    /// `@DependencyEntry(Some.Key.self)` names the key; the macro drops the trailing `.self`.
    private static func explicitKey(_ node: AttributeSyntax) -> String? {
        guard case let .argumentList(arguments) = node.arguments,
              let expression = arguments.first?.expression
        else {
            return nil
        }
        if let member = expression.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "self",
           let base = member.base {
            return base.trimmedDescription
        }
        return expression.trimmedDescription
    }

    private static func inferredKey(from type: TypeSyntax) -> String {
        if let existential = type.as(SomeOrAnyTypeSyntax.self), existential.someOrAnySpecifier.text == "any" {
            return "\(existential.constraint.trimmedDescription).Key"
        }
        return type.trimmedDescription
    }
}

enum DependencyEntryMacroError: Error, CustomStringConvertible {
    case notAPlainProperty

    var description: String {
        "@DependencyEntry requires one 'var' with a type annotation, no initial value, and no accessors."
    }
}
