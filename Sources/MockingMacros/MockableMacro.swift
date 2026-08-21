//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct MockableMacro: ExtensionMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try [mockableStructExtension(for: structDecl)]
        }

        if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            if MacroSyntaxSupport.hasAssociatedTypes(protocolDecl) {
                // The peer role reports this and emits no class; don't dangle an alias to a missing type.
                guard !protocolHasStaticRequirement(protocolDecl) else { return [] }
                // A generic mock has no single concrete `Self`, so the `where Self == Mock` fixture accessor
                // can't be formed; only the unbound `Mock` alias applies.
                return try [mockAliasExtension(for: protocolDecl, in: context)]
            }
            return try [
                mockAccessorExtension(for: protocolDecl, in: context),
                mockAliasExtension(for: protocolDecl, in: context),
            ]
        }

        return []
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            return []
        }

        let baseIndentLevel = 0
        let mockClassName = MacroSyntaxSupport.mockClassName(for: protocolDecl.name.text)
        let access = MacroSyntaxSupport.accessModifier(for: protocolDecl)
        let generics = MacroSyntaxSupport.associatedTypeGenerics(for: protocolDecl)

        // A generic type can't hold `static let` peers, which is how static requirements are mocked.
        if !generics.clause.isEmpty, protocolHasStaticRequirement(protocolDecl) {
            throw MockableMacroError.staticRequirementInGenericProtocol
        }

        let members = peerMacroMembers(
            from: protocolDecl,
            mockClassName: mockClassName,
            access: access,
            bodyIndentLevel: baseIndentLevel + 1
        )

        let source = MacroSyntaxSupport.protocolMockSource(
            mockClassName: mockClassName,
            protocolName: protocolDecl.name.text,
            access: access,
            members: members,
            baseIndentLevel: baseIndentLevel,
            genericClause: generics.clause,
            whereClause: generics.whereClause
        )

        return [try MacroSyntaxSupport.parseDeclaration(source)]
    }

    private static func protocolHasStaticRequirement(_ protocolDecl: ProtocolDeclSyntax) -> Bool {
        protocolDecl.memberBlock.members.contains { member in
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                return MacroSyntaxSupport.isStatic(function.modifiers)
            }
            if let property = member.decl.as(VariableDeclSyntax.self) {
                return MacroSyntaxSupport.isStatic(property.modifiers)
            }
            return false
        }
    }

    private static func mockAccessorExtension(
        for protocolDecl: ProtocolDeclSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        let mockClassName = MacroSyntaxSupport.mockClassName(for: protocolDecl.name.text)
        let access = MacroSyntaxSupport.accessModifier(for: protocolDecl)
        let protocolName = MacroSyntaxSupport.qualifiedProtocolName(for: protocolDecl, in: context)
        let mockTypeName = MacroSyntaxSupport.qualifiedMockTypeName(
            for: protocolDecl,
            in: context,
            mockClassName: mockClassName
        )

        let source = """
        extension \(protocolName) {
            #if MOCKING
            \(access)static var mock: \(mockTypeName) { \(mockTypeName)() }
            #endif
        }
        """

        return try parseExtension(source)
    }

    /// `extension Greeter { typealias Mock = GreeterMock }` — makes `Greeter.Mock()` resolve to the peer,
    /// unifying the controller spelling with struct witnesses (`TokenStore.Mock()`).
    private static func mockAliasExtension(
        for protocolDecl: ProtocolDeclSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        let mockClassName = MacroSyntaxSupport.mockClassName(for: protocolDecl.name.text)
        let access = MacroSyntaxSupport.accessModifier(for: protocolDecl)
        let protocolName = MacroSyntaxSupport.qualifiedProtocolName(for: protocolDecl, in: context)
        let mockTypeName = MacroSyntaxSupport.qualifiedMockTypeName(
            for: protocolDecl,
            in: context,
            mockClassName: mockClassName
        )

        let source = """
        extension \(protocolName) {
            #if MOCKING
            \(access)typealias Mock = \(mockTypeName)
            #endif
        }
        """

        return try parseExtension(source)
    }

    /// Every `@Mockable` struct gets the same controller grammar as a protocol: a nested `Mock` with `$` peers,
    /// `init(mock:)`, `instance`, and a lenient `mock`. Closure properties become `Mock.Method` peers (full
    /// config + verification); value properties become `Mock.Property.Get` peers (configure-only fixtures).
    private static func mockableStructExtension(for structDecl: StructDeclSyntax) throws -> ExtensionDeclSyntax {
        let properties = collectStoredProperties(structDecl.memberBlock)
        guard !properties.isEmpty else {
            throw MockableMacroError.structHasNoMockableProperties
        }
        guard !declaresNestedMockType(structDecl.memberBlock) else {
            throw MockableMacroError.witnessMockCollision
        }

        // The nested `Mock` inherits the struct's generic context, so generic structs need no special
        // generation — only value peers whose type mentions a parameter must wire leniently (see below).
        let structName = structDecl.name.text
        let access = MacroSyntaxSupport.accessModifier(for: structDecl)
        let genericParameters = Set(
            structDecl.genericParameterClause?.parameters.map(\.name.text) ?? []
        )
        let witnessed = try properties.map {
            try WitnessMockMacroSupport.property(
                name: $0.name,
                type: $0.type,
                defaultValue: $0.defaultValue,
                access: $0.access,
                genericParameters: genericParameters
            )
        }

        let peers = witnessed.map(\.peerDeclaration).joined(separator: "\n\n")
        let wiring = witnessed.map(\.wiringExpression).joined(separator: ",\n")

        let source = """
        extension \(structName): Mockable {
            #if MOCKING
            \(access)final class Mock: Sendable, MockWithable {
                \(peers)

                \(access)init() {
                }

                \(access)var instance: \(structName) {
                    \(structName)(mock: self)
                }
            }

            \(access)static var mock: \(structName) {
                Mock().instance
            }

            \(access)init(mock: Mock) {
                self.init(
                    \(wiring)
                )
            }
            #endif
        }
        """

        return try parseExtension(source)
    }

    private static func peerMacroMembers(
        from protocolDecl: ProtocolDeclSyntax,
        mockClassName: String,
        access: String,
        bodyIndentLevel: Int
    ) -> [String] {
        let memberIndent = MacroSyntaxSupport.indent(level: bodyIndentLevel)
        var members: [String] = []

        for member in protocolDecl.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                let signature = MacroSyntaxSupport.functionSignature(from: function)
                members.append("\(memberIndent)@MockedMethod\n\(memberIndent)\(access)\(signature)")
            }

            if let property = member.decl.as(VariableDeclSyntax.self),
               let binding = property.bindings.first,
               let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
               let typeAnnotation = binding.typeAnnotation?.type {
                let valueType = MacroSyntaxSupport.typeName(from: typeAnnotation)
                let kind = MockedPropertyMacroSupport.inferredPropertyKind(for: property, binding: binding)
                let attribute = MockedPropertyMacroSupport.mockedPropertyAttribute(for: kind)
                let staticKeyword = MacroSyntaxSupport.staticKeyword(property.modifiers)
                let declaration = "\(access)\(staticKeyword)var \(identifier): \(valueType)"
                members.append("\(memberIndent)\(attribute)\n\(memberIndent)\(declaration)")
            }
        }

        members.append("\(memberIndent)\(access)init() {}")
        members.append("\(memberIndent)\(access)var instance: \(mockClassName) { self }")
        return members
    }

    private static func collectStoredProperties(_ memberBlock: MemberBlockSyntax) -> [StoredProperty] {
        memberBlock.members.compactMap { member -> StoredProperty? in
            guard
                let property = member.decl.as(VariableDeclSyntax.self),
                !MacroSyntaxSupport.isStatic(property.modifiers),
                property.bindingSpecifier.text == "var" || property.bindingSpecifier.text == "let",
                let binding = property.bindings.first,
                binding.accessorBlock == nil,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let typeAnnotation = binding.typeAnnotation?.type
            else {
                return nil
            }
            return StoredProperty(
                name: identifier,
                type: typeAnnotation,
                defaultValue: binding.initializer?.value.trimmedDescription,
                access: MacroSyntaxSupport.accessModifier(from: property.modifiers)
            )
        }
    }

    private static func declaresNestedMockType(_ memberBlock: MemberBlockSyntax) -> Bool {
        memberBlock.members.contains { member in
            if let nested = member.decl.as(StructDeclSyntax.self) { return nested.name.text == "Mock" }
            if let nested = member.decl.as(ClassDeclSyntax.self) { return nested.name.text == "Mock" }
            if let nested = member.decl.as(EnumDeclSyntax.self) { return nested.name.text == "Mock" }
            if let nested = member.decl.as(TypeAliasDeclSyntax.self) { return nested.name.text == "Mock" }
            return false
        }
    }

    private static func parseExtension(_ source: String) throws -> ExtensionDeclSyntax {
        let parsed = try MacroSyntaxSupport.parseDeclaration(source)
        guard let extensionDecl = parsed.as(ExtensionDeclSyntax.self) else {
            throw MockableMacroError.failedToGenerateExtension
        }
        return extensionDecl
    }
}

struct StoredProperty {
    let name: String
    let type: TypeSyntax
    let defaultValue: String?
    /// Access on the stored property itself — peers mirror this, not the enclosing type.
    let access: String
}

enum MockableMacroError: Error, CustomStringConvertible {
    case structHasNoMockableProperties
    case failedToGenerateExtension
    case staticRequirementInGenericProtocol
    case witnessMockCollision
    case unsupportedClosureParameter

    var description: String {
        switch self {
        case .structHasNoMockableProperties:
            "@Mockable requires at least one stored property on the struct."
        case .failedToGenerateExtension:
            "@Mockable failed to synthesize a Mockable extension."
        case .staticRequirementInGenericProtocol:
            "@Mockable cannot mock static requirements on a protocol with associated types."
        case .witnessMockCollision:
            "@Mockable cannot synthesize a mock: 'Mock' is already declared. Rename the nested type."
        case .unsupportedClosureParameter:
            "@Mockable does not support 'inout' or variadic parameters in closure properties."
        }
    }
}
