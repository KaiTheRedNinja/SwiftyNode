//
//  NativeMethodGroupMacro.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 7/9/24.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

import SwiftyNodeKit

public struct NativeMethodGroupMacro: ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            throw NodeMacroError.notProtocol
        }

        // the protocol must conform to NativeMethodGroupProtocol
        guard
            proto
                .inheritanceClause?
                .inheritedTypes
                .contains(where: { $0.type.description.contains("NativeMethodGroupProtocol") }) ?? false
        else {
            throw NodeMacroError.notConform
        }

        let name = proto.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let access = proto.access

        for function in proto.functions {
            guard function.effects == ["async", "throws"] else {
                throw NodeMacroError.notAsyncThrows
            }
            guard function.returnType?.hasSuffix("?") ?? true else {
                throw NodeMacroError.notOptional
            }
        }

        let extensionDecl = Declaration(
            "extension \(name) where Self: NativeMethodGroupProtocol"
        ) {
            Declaration(
                "func registerWithCommunicator(_ communicator: NodeCommunicator)"
            ) {
                Declaration("Task") {
                    for function in proto.functions {
                        methodRegistration(for: function)
                    }
                }
            }
        }
        .access(access)

        guard let extensionDecl = extensionDecl.declSyntax().as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }

    private static func methodRegistration(for function: FunctionDeclSyntax) -> [Declaration] {
        let funcName = function.name

        var declParameters: [String] = []
        for param in function.parameters {
            let firstName = param.firstName.text
            let type = param.type

            @DeclarationsBuilder
            func getObject() -> [Declaration] {
                """
                    let \(firstName)Param: \(type) = if let param = params?[\"\(firstName)\"] as? \(type) {
                        param
                    } else {
                """

                if !type.is(OptionalTypeSyntax.self) {
                    """
                            throw JSONResponseError.invalidParams
                    """
                } else {
                    """
                            nil
                    """
                }

                "    }\n"
            }

            declParameters.append(getObject().map { $0.formattedString() }.joined(separator: "\n"))
        }

        @DeclarationsBuilder
        func registration() -> [Declaration] {
            """
            await communicator.register(methodName: "\(funcName)") { params in
            """

            for declParam in declParameters {
                declParam
            }

            """
                return try await \(funcName)(
            """

            let paramCount = function.parameters.count
            for (index, declParam) in function.parameters.enumerated() {
                let firstName = declParam.firstName.text
                let trailingComma = if index < paramCount - 1 { "," } else { "" }
                String(repeating: " ", count: 8) + "\(firstName): \(firstName)Param" + trailingComma
            }

            """
                )
            }
            """
        }

        return registration()
    }
}
