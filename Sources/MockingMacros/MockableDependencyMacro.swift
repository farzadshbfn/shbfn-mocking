//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// `@Mockable`, plus a swift-dependencies key whose test value is an exclusive mock.
/// It takes a protocol without associated types, or a non-generic struct.
public struct MockableDependencyMacro: ExtensionMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let names = Names(declaration, in: context)
        let mockExtensions: [ExtensionDeclSyntax]
        switch try dependencyDeclaration(declaration) {
        case let .protocol(protocolDecl):
            mockExtensions = try MockableMacro.expansion(
                of: node,
                attachedTo: protocolDecl,
                providingExtensionsOf: type,
                conformingTo: protocols,
                in: context
            )
        case .struct:
            // The mock is a peer class; the extension only names it, so no type in it needs the struct's scope.
            let source = """
            extension \(names.qualifiedType): Mockable {
                #if DEBUG || MOCKING
                \(names.access)typealias Mock = \(names.qualifiedMockClass)

                \(names.access)static var mock: \(names.qualifiedType) {
                    Mock().instance
                }
                #endif
            }
            """
            guard let mockExtension = try MacroSyntaxSupport.parseDeclaration(source).as(ExtensionDeclSyntax.self)
            else {
                throw MockableMacroError.failedToGenerateExtension
            }
            mockExtensions = [mockExtension]
        }
        // An extension macro can only extend the attached type, so `@DependencyEntry` writes the accessor.
        let alias = """
        extension \(names.qualifiedType) {
            \(names.access)typealias Key = \(names.qualifiedKey)
        }
        """
        guard let aliasExtension = try MacroSyntaxSupport.parseDeclaration(alias).as(ExtensionDeclSyntax.self) else {
            throw MockableMacroError.failedToGenerateExtension
        }
        return mockExtensions + [aliasExtension]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The extension role reports a declaration that cannot be a key, so this role emits nothing for it.
        guard let group = declaration.asProtocol(DeclGroupSyntax.self),
              let kind = try? dependencyDeclaration(group)
        else { return [] }
        let names = Names(group, in: context)
        let mock: [DeclSyntax]
        let testValue: String
        switch kind {
        case let .protocol(protocolDecl):
            mock = try MockableMacro.protocolMockPeers(for: protocolDecl, in: context, addsExclusive: true)
            testValue = "\(names.qualifiedMockClass)().exclusive()"
        case let .struct(structDecl):
            mock = [
                try MockableMacro.structMockPeer(
                    for: structDecl,
                    mockClassName: MacroSyntaxSupport.mockClassName(for: structDecl.name.text)
                ),
            ]
            testValue = "\(names.qualifiedMockClass)().exclusive().instance"
        }
        let key = """
        \(names.access)enum \(names.key): Dependencies.TestDependencyKey {
            \(names.access)static var testValue: \(names.valueType) {
                #if DEBUG || MOCKING
                \(testValue)
                #else
                fatalError("\(names.qualifiedType) has no test value in this build.")
                #endif
            }
        }
        """
        return mock + [try MacroSyntaxSupport.parseDeclaration(key)]
    }

    private enum Kind {
        case `protocol`(ProtocolDeclSyntax)
        case `struct`(StructDeclSyntax)
    }

    private static func dependencyDeclaration(_ declaration: some DeclGroupSyntax) throws -> Kind {
        if let protocolDecl = declaration.as(ProtocolDeclSyntax.self),
           !MacroSyntaxSupport.hasAssociatedTypes(protocolDecl) {
            return .protocol(protocolDecl)
        }
        if let structDecl = declaration.as(StructDeclSyntax.self), structDecl.genericParameterClause == nil {
            return .struct(structDecl)
        }
        throw MockableDependencyMacroError.notADependencyDeclaration
    }
}

/// Every name the expansion spells, resolved from the type and its enclosing types.
private struct Names {
    let access: String
    let qualifiedType: String
    /// `any P` for a protocol, the struct itself for a struct.
    let valueType: String
    let key: String
    let qualifiedKey: String
    let qualifiedMockClass: String

    init(_ declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) {
        let name = declaration.as(ProtocolDeclSyntax.self)?.name.text
            ?? declaration.as(StructDeclSyntax.self)?.name.text
            ?? ""
        access = MacroSyntaxSupport.accessModifier(for: declaration)
        qualifiedType = MacroSyntaxSupport.qualifiedName(name, in: context)
        valueType = declaration.is(ProtocolDeclSyntax.self) ? "any \(qualifiedType)" : qualifiedType
        let parent = qualifiedType.split(separator: ".").dropLast().joined(separator: ".")
        let prefix = parent.isEmpty ? "" : "\(parent)."
        key = "\(name)Key"
        qualifiedKey = prefix + key
        qualifiedMockClass = prefix + MacroSyntaxSupport.mockClassName(for: name)
    }
}

enum MockableDependencyMacroError: Error, CustomStringConvertible {
    case notADependencyDeclaration

    var description: String {
        """
        @MockableDependency requires a protocol without associated types or a non-generic struct, \
        because its key holds one concrete value type.
        """
    }
}
