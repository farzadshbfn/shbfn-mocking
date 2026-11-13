//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// `@Mockable`, plus a swift-dependencies key whose test value is an exclusive mock.
public struct MockableDependencyMacro: ExtensionMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        _ = try dependencyProtocol(declaration)
        // An extension macro can only extend the protocol, so the `DependencyValues` accessor stays hand-written.
        return try MockableMacro.expansion(
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The extension role reports a protocol that cannot be a key, so this role emits nothing for it.
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self),
              !MacroSyntaxSupport.hasAssociatedTypes(protocolDecl)
        else { return [] }
        let mock = try MockableMacro.protocolMockPeers(for: protocolDecl, in: context, addsExclusive: true)
        let names = Names(protocolDecl, in: context)
        let key = """
        \(names.access)enum \(names.key): Dependencies.TestDependencyKey {
            \(names.access)static var testValue: any \(names.qualifiedProtocol) {
                #if DEBUG || MOCKING
                \(names.qualifiedMock)().exclusive()
                #else
                fatalError("\(names.qualifiedProtocol) has no test value in this build.")
                #endif
            }
        }
        """
        return mock + [try MacroSyntaxSupport.parseDeclaration(key)]
    }

    private static func dependencyProtocol(_ declaration: some DeclGroupSyntax) throws -> ProtocolDeclSyntax {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self),
              !MacroSyntaxSupport.hasAssociatedTypes(protocolDecl)
        else {
            throw MockableDependencyMacroError.notAPlainProtocol
        }
        return protocolDecl
    }
}

/// Every name the expansion spells, resolved from the protocol and its enclosing types.
private struct Names {
    let access: String
    let qualifiedProtocol: String
    let key: String
    let qualifiedMock: String

    init(_ protocolDecl: ProtocolDeclSyntax, in context: some MacroExpansionContext) {
        let name = protocolDecl.name.text
        access = MacroSyntaxSupport.accessModifier(for: protocolDecl)
        qualifiedProtocol = MacroSyntaxSupport.qualifiedProtocolName(for: protocolDecl, in: context)
        let parent = qualifiedProtocol.split(separator: ".").dropLast().joined(separator: ".")
        let prefix = parent.isEmpty ? "" : "\(parent)."
        key = "\(name)Key"
        qualifiedMock = prefix + MacroSyntaxSupport.mockClassName(for: name)
    }
}

enum MockableDependencyMacroError: Error, CustomStringConvertible {
    case notAPlainProtocol

    var description: String {
        "@MockableDependency requires a protocol without associated types, because its key holds 'any Protocol'."
    }
}
