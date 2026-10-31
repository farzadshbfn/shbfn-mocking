//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros

// swiftlint:disable type_body_length
enum MacroSyntaxSupport {
    static func parseDeclaration(_ source: String) throws -> DeclSyntax {
        guard let declaration = try parseDeclarations(source).first else {
            throw MacroSyntaxSupportError.failedToParseDeclaration(source)
        }
        return declaration
    }

    static func parseDeclarations(_ source: String) throws -> [DeclSyntax] {
        let file = Parser.parse(source: source)
        let declarations = file.statements.compactMap { statement -> DeclSyntax? in
            guard case let .decl(declaration) = statement.item else { return nil }
            return DeclSyntax(declaration)
        }
        guard !declarations.isEmpty else {
            throw MacroSyntaxSupportError.failedToParseDeclaration(source)
        }
        return declarations
    }

    static func indent(level: Int) -> String {
        String(repeating: "    ", count: level)
    }

    static func qualifiedProtocolName(
        for protocolDecl: ProtocolDeclSyntax,
        in context: some MacroExpansionContext
    ) -> String {
        var components = [protocolDecl.name.text]

        for syntax in context.lexicalContext {
            if let extensionDecl = syntax.as(ExtensionDeclSyntax.self) {
                components.insert(typeName(from: extensionDecl.extendedType), at: 0)
            }
            if let enumDecl = syntax.as(EnumDeclSyntax.self) {
                components.insert(enumDecl.name.text, at: 0)
            }
            if let structDecl = syntax.as(StructDeclSyntax.self) {
                components.insert(structDecl.name.text, at: 0)
            }
            if let classDecl = syntax.as(ClassDeclSyntax.self) {
                components.insert(classDecl.name.text, at: 0)
            }
        }

        return components.joined(separator: ".")
    }

    static func qualifiedMockTypeName(
        for protocolDecl: ProtocolDeclSyntax,
        in context: some MacroExpansionContext,
        mockClassName: String
    ) -> String {
        let qualifiedProtocol = qualifiedProtocolName(for: protocolDecl, in: context)
        guard let dotIndex = qualifiedProtocol.lastIndex(of: ".") else {
            return mockClassName
        }
        let parentPath = String(qualifiedProtocol[..<dotIndex])
        return "\(parentPath).\(mockClassName)"
    }

    static func protocolMockSource(
        mockClassName: String,
        protocolName: String,
        access: String,
        members: [String],
        baseIndentLevel: Int,
        genericClause: String = "",
        whereClause: String = ""
    ) -> String {
        let outer = indent(level: baseIndentLevel)
        let memberBlock = members.joined(separator: "\n\n")
        let header = "\(access)final class \(mockClassName)\(genericClause): \(protocolName), Sendable, MockWithable"
        return """
        \(outer)#if DEBUG || MOCKING
        \(outer)\(header)\(whereClause) {
        \(memberBlock)
        \(outer)}
        \(outer)#endif
        """
    }

    /// Access level keyword from the declaration (`public`, `package`, `internal`, …), including a
    /// trailing space for splicing into generated source. Empty when no access modifier is written.
    static func accessModifier(for declaration: some DeclGroupSyntax) -> String {
        accessModifier(from: declaration.modifiers)
    }

    static func accessModifier(from modifiers: DeclModifierListSyntax) -> String {
        let accessKeywords: Set<String> = [
            "private", "fileprivate", "internal", "package", "public",
        ]
        guard let modifier = modifiers.first(where: { accessKeywords.contains($0.name.text) }) else {
            return ""
        }
        return "\(modifier.name.text) "
    }

    /// Peer output type. Erases to `Any` when the return type mentions a method-level generic.
    static func outputType(from function: FunctionDeclSyntax) -> String {
        guard let returnType = function.signature.returnClause?.type else { return "Void" }
        let generics = methodGenericParameters(from: function)
        if mentionsGenericParameter(returnType, generics) {
            return "Any"
        }
        return mockTypeName(from: returnType)
    }

    static func mockPeerName(for identifier: String) -> String {
        "$\(identifier)"
    }

    /// Peer name the user asked for, as `@MockedMethod(named: "run2")`. Nil when they wrote none.
    /// A non-literal argument throws, because the macro must read the name at compile time.
    static func customPeerName(from attribute: AttributeSyntax) throws -> String? {
        guard
            let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
            let argument = arguments.first(where: { $0.label?.text == "named" })
        else {
            return nil
        }
        guard let name = stringLiteralValue(argument.expression) else {
            throw MockedMacroError.peerNameIsNotALiteral(argument.expression.trimmedDescription)
        }
        guard isIdentifier(name) else {
            throw MockedMacroError.peerNameIsNotAnIdentifier(name)
        }
        return name
    }

    /// `@MockedMethod` or `@MockedProperty` written by the user on this member.
    static func mockedAttribute(on attributes: AttributeListSyntax) -> AttributeSyntax? {
        for attribute in attributes {
            guard let attribute = attribute.as(AttributeSyntax.self) else { continue }
            let name = attribute.attributeName.trimmedDescription
            if name == "MockedMethod" || name == "MockedProperty" {
                return attribute
            }
        }
        return nil
    }

    /// True when the declaration sits directly inside a protocol. `@Mockable` reads the member's
    /// own `@MockedMethod` there, so the attribute must add nothing of its own.
    static func isInsideProtocol(_ context: some MacroExpansionContext) -> Bool {
        context.lexicalContext.first?.is(ProtocolDeclSyntax.self) ?? false
    }

    static func stringLiteralValue(_ expression: ExprSyntax) -> String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else { return nil }
        var text = ""
        for segment in literal.segments {
            guard case let .stringSegment(piece) = segment else { return nil }
            text += piece.content.text
        }
        return text
    }

    /// A generated peer becomes `$name`, so the name must be a plain Swift identifier.
    static func isIdentifier(_ name: String) -> Bool {
        guard let first = name.first else { return false }
        guard first == "_" || first.isLetter else { return false }
        return name.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    }

    static func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.text == "static" }
    }

    static func mockPeerStorage(peerName: String, factory: String, isStatic: Bool, access: String) -> String {
        if isStatic {
            return "\(access)static let \(peerName) = \(factory)"
        }
        return "\(access)nonisolated let \(peerName) = \(factory)"
    }

    static func mockPeerDeclarations(
        peerName: String,
        factory: String,
        isStatic: Bool,
        access: String
    ) throws -> [DeclSyntax] {
        try parseDeclarations("""
        #if DEBUG || MOCKING
        \(mockPeerStorage(peerName: peerName, factory: factory, isStatic: isStatic, access: access))
        #endif
        """)
    }

    static func propertySubject(from property: VariableDeclSyntax, identifier: String) -> String {
        isStatic(property.modifiers) ? "static \(identifier)" : identifier
    }

    static func staticKeyword(_ modifiers: DeclModifierListSyntax) -> String {
        isStatic(modifiers) ? "static " : ""
    }

    static func mockClassName(for protocolName: String) -> String {
        "\(protocolName)Mock"
    }

    static func typeName(from type: TypeSyntax) -> String {
        type.trimmedDescription
    }

    /// Types used in `Mock.Method` / `Mock.Property` generics. IUO spellings are normalized to `?`.
    static func mockTypeName(from type: TypeSyntax) -> String {
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return "\(mockTypeName(from: iuo.wrappedType))?"
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return "\(mockTypeName(from: optional.wrappedType))?"
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            return "[\(mockTypeName(from: array.element))]"
        }
        if let dict = type.as(DictionaryTypeSyntax.self) {
            return "[\(mockTypeName(from: dict.key)): \(mockTypeName(from: dict.value))]"
        }
        if let tuple = type.as(TupleTypeSyntax.self) {
            let elements = tuple.elements.map { element -> String in
                let name = element.secondName?.text ?? element.firstName?.text
                let elementType = mockTypeName(from: element.type)
                if let name, name != "_" {
                    return "\(name): \(elementType)"
                }
                return elementType
            }
            return "(\(elements.joined(separator: ", ")))"
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return "\(mockTypeName(from: member.baseType)).\(member.name.text)"
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return mockTypeName(from: attributed.baseType)
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.map { mockTypeName(from: $0.type) }.joined(separator: " & ")
        }
        return type.trimmedDescription
    }

    /// External argument label used for mock input tuple fields and `args` ergonomics.
    static func functionParameterLabel(for param: FunctionParameterSyntax, index: Int) -> String {
        let externalName = param.firstName.text
        if externalName != "_" {
            return externalName
        }
        if let internalName = param.secondName?.text, internalName != "_" {
            return internalName
        }
        return "arg\(index)"
    }

    /// Internal parameter name used in generated method bodies.
    static func functionParameterVariableName(for param: FunctionParameterSyntax, index: Int) -> String {
        if let internalName = param.secondName?.text, internalName != "_" {
            return internalName
        }
        let externalName = param.firstName.text
        if externalName != "_" {
            return externalName
        }
        return "arg\(index)"
    }

    static func functionInputsType(from node: FunctionDeclSyntax) -> String {
        let generics = methodGenericParameters(from: node)
        let params = node.signature.parameterClause.parameters
        guard !params.isEmpty else { return "Void" }
        // Single-element labeled tuples don't exist in Swift, so a lone parameter is always unlabeled.
        if params.count == 1 {
            return erasedInputTypeName(from: params.first!.type, genericParameters: generics)
        }
        let fields = params.enumerated().map { index, param in
            let label = functionParameterLabel(for: param, index: index)
            return "\(label): \(erasedInputTypeName(from: param.type, genericParameters: generics))"
        }
        return "(\(fields.joined(separator: ", ")))"
    }

    static func isAsync(_ node: FunctionDeclSyntax) -> Bool {
        node.signature.effectSpecifiers?.asyncSpecifier != nil
    }

    static func isThrowing(_ node: FunctionDeclSyntax) -> Bool {
        node.signature.effectSpecifiers?.throwsClause != nil
    }

    /// Unwraps optional, IUO, attributed, and single-element-tuple spellings to reach a closure type, if any.
    static func functionType(from type: TypeSyntax) -> FunctionTypeSyntax? {
        if let function = type.as(FunctionTypeSyntax.self) { return function }
        if let attributed = type.as(AttributedTypeSyntax.self) { return functionType(from: attributed.baseType) }
        if let optional = type.as(OptionalTypeSyntax.self) { return functionType(from: optional.wrappedType) }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return functionType(from: iuo.wrappedType) }
        if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
            return functionType(from: tuple.elements.first!.type)
        }
        return nil
    }

    static func containsFunctionType(_ type: TypeSyntax) -> Bool {
        if type.is(FunctionTypeSyntax.self) {
            return true
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return containsFunctionType(attributed.baseType)
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return containsFunctionType(optional.wrappedType)
        }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return containsFunctionType(iuo.wrappedType)
        }
        return false
    }

    /// Preserves function-type shape for mock generics; strips `@escaping` (invalid outside parameters).
    static func functionInputTypeName(from type: TypeSyntax) -> String {
        let name = containsFunctionType(type) ? typeName(from: type) : mockTypeName(from: type)
        return name.replacing("@escaping ", with: "")
    }

    static func methodSubject(from node: FunctionDeclSyntax) -> String {
        let staticPrefix = isStatic(node.modifiers) ? "static " : ""
        let params = node.signature.parameterClause.parameters
        guard !params.isEmpty else {
            return "\(staticPrefix)\(node.name.text)()"
        }
        let labels = params.map { param -> String in
            let externalLabel = param.firstName.text
            if externalLabel == "_" {
                return "_:"
            }
            let internalLabel = param.secondName?.text ?? externalLabel
            if externalLabel == internalLabel {
                return "\(externalLabel):"
            }
            return "\(externalLabel) \(internalLabel):"
        }.joined()
        return "\(staticPrefix)\(node.name.text)(\(labels))"
    }

    static func methodFactory(for node: FunctionDeclSyntax, outputType: String) -> String {
        invocationFactory(
            inputs: functionInputsType(from: node),
            output: outputType,
            isAsync: isAsync(node),
            failure: methodFailureType(from: node),
            subject: methodSubject(from: node)
        )
    }

    /// Runtime types are always spelled `Mocking.Mock.*`. Protocol mocks inherit a `Mock` typealias from the
    /// `@Mockable` protocol, and witness controllers are themselves named `Mock`; both shadow the bare `Mock` enum.
    static let runtimeNamespace = "Mocking."

    /// Untyped `throws` failure type. Fully qualified so a nested `Error` (repo convention) cannot shadow it.
    static let anyError = "any Swift.Error"

    /// Builds a `Mock.Method` invocation factory shared by protocol methods and struct-witness closures.
    static func invocationFactory(
        inputs: String,
        output: String,
        isAsync: Bool,
        failure: String?,
        subject: String,
        namespace: String = runtimeNamespace
    ) -> String {
        let base = "\(namespace)Mock.Method<\(inputs), \(output)>"
        let subjectArg = "subject: \"\(subject)\""
        switch (isAsync, failure) {
        case let (true, failure?): return "\(base).AsyncThrows<\(failure)>(\(subjectArg))"
        case (true, nil): return "\(base).Async(\(subjectArg))"
        case let (false, failure?): return "\(base).SyncThrows<\(failure)>(\(subjectArg))"
        case (false, nil): return "\(base).Sync(\(subjectArg))"
        }
    }
}
// swiftlint:enable type_body_length

enum MacroSyntaxSupportError: Error, CustomStringConvertible {
    case failedToParseDeclaration(String)

    var description: String {
        switch self {
        case let .failedToParseDeclaration(source):
            "Failed to parse generated macro declaration:\n\(source)"
        }
    }
}
