//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if MOCKING
public struct MockedMethodMacro: PeerMacro, BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            throw MockedMacroError.unsupportedMethodDeclaration
        }

        let peerName = MacroSyntaxSupport.mockPeerName(for: function.name.text)
        let outputType = MacroSyntaxSupport.outputType(from: function)
        let factory = MacroSyntaxSupport.methodFactory(for: function, outputType: outputType)
        return try MacroSyntaxSupport.mockPeerDeclarations(
            peerName: peerName,
            factory: factory,
            isStatic: MacroSyntaxSupport.isStatic(function.modifiers),
            access: MacroSyntaxSupport.accessModifier(from: function.modifiers)
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        let peerName = MacroSyntaxSupport.mockPeerName(for: function.name.text)
        return MacroSyntaxSupport.methodBodyStatements(for: function, peerName: peerName)
    }
}

public struct MockedPropertyMacro: PeerMacro, AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard
            let property = declaration.as(VariableDeclSyntax.self),
            let binding = property.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let typeAnnotation = binding.typeAnnotation?.type
        else {
            throw MockedMacroError.unsupportedPropertyDeclaration
        }

        let kind = try MockedPropertyMacroSupport.parseMockedPropertyKind(
            from: node,
            property: property,
            binding: binding
        )
        let peerName = MacroSyntaxSupport.mockPeerName(for: identifier)
        let valueType = MacroSyntaxSupport.mockTypeName(from: typeAnnotation)
        let subject = MacroSyntaxSupport.propertySubject(from: property, identifier: identifier)
        let factory = MockedPropertyMacroSupport.propertyFactory(
            for: kind,
            valueType: valueType,
            subject: subject
        )
        return try MacroSyntaxSupport.mockPeerDeclarations(
            peerName: peerName,
            factory: factory,
            isStatic: MacroSyntaxSupport.isStatic(property.modifiers),
            access: MacroSyntaxSupport.accessModifier(from: property.modifiers)
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard
            let property = declaration.as(VariableDeclSyntax.self),
            let binding = property.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        else {
            return []
        }

        let kind = try MockedPropertyMacroSupport.parseMockedPropertyKind(
            from: node,
            property: property,
            binding: binding
        )
        let peerName = MacroSyntaxSupport.mockPeerName(for: identifier)
        let getCall = MockedPropertyMacroSupport.propertyGetCall(for: kind, peerName: peerName)
        let getKeyword = MockedPropertyMacroSupport.getterAccessorKeyword(for: kind)

        let getAccessor = try AccessorDeclSyntax("\(raw: getKeyword)") {
            "return \(raw: getCall)"
        }

        let hasSetter = MockedPropertyMacroSupport.propertyEmitsSetAccessor(for: kind)
        if hasSetter {
            return [
                getAccessor,
                AccessorDeclSyntax(accessorSpecifier: .keyword(.set)) {
                    "\(raw: peerName).set.result(newValue)"
                },
            ]
        }

        return [getAccessor]
    }
}
#endif

enum MockedMacroError: Error, CustomStringConvertible {
    case unsupportedMethodDeclaration
    case unsupportedPropertyDeclaration

    var description: String {
        switch self {
        case .unsupportedMethodDeclaration:
            "@MockedMethod can only be applied to functions."
        case .unsupportedPropertyDeclaration:
            "@MockedProperty can only be applied to properties."
        }
    }
}
