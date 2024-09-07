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
                        let funcName = function.name
                    """
                    await communicator.register(methodName: "\(funcName)") { params in
                        // TODO: get the parameters
                        return nil
                    }
                    """
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
}
