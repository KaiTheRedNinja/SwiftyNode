//
//  NodeMethodGroupMacro.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 7/9/24.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

import Log
import SwiftyNodeKit

public struct NodeMethodGroupMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            throw NodeMacroError.notProtocol
        }

        let name = proto.name
        let access = proto.access

        for function in proto.functions {
            guard function.effects == ["async", "throws"] else {
                throw NodeMacroError.notAsyncThrows
            }
            guard function.returnType?.hasSuffix("?") ?? true else {
                throw NodeMacroError.notOptional
            }
        }

        return [
            Declaration("class \(name.text.trimmingCharacters(in: .whitespacesAndNewlines))MethodGroup: \(name)") {
                // 0. provider reference & init

                "private let communicator: NodeCommunicator"

                Declaration("init(communicator: NodeCommunicator)") {
                    "self.communicator = communicator"
                }
                .access(access)

                for function in proto.functions {
                    methodImplementation(for: function)
                }
            }
            .declSyntax()
        ]
    }

    private static func methodImplementation(for function: FunctionDeclSyntax) -> Declaration {
        var functionParameters: [String] = []
        var callParameters: [String] = []
        for param in function.parameters {
            let firstName = param.firstName.text
            let secondName = if let second = param.secondName {
                " " + second.text
            } else {
                ""
            }
            let type = param.type

            functionParameters.append("\(firstName)\(secondName): \(type)")
            callParameters.append("\"\(param.firstName.text)\": \(param.secondName?.text ?? param.firstName.text)")
        }

        let functionReturnType = if let ret = function.returnType { " -> \(ret)" } else { "" }

        let notify = function.returnType == nil

        return Declaration(
            "func \(function.name)(\(functionParameters.joined(separator: ", "))) async throws\(functionReturnType)"
        ) {
            let functionToCall = notify ? "notify" : "request"

            """
            try await communicator.\(functionToCall)(
                method: "\(function.name)",
            """
            if !callParameters.isEmpty {
                """
                    params: [
                """

                let paramCount = function.parameters.count
                for (index, callParam) in callParameters.enumerated() {
                    let trailingComma = if index < paramCount - 1 { "," } else { "" }
                    String(repeating: " ", count: 8) + callParam + trailingComma
                }

                """
                    ]\(notify ? "" : ",")
                """
            } else {
                """
                    params: nil\(notify ? "" : ",")
                """
            }

            if !notify {
                """
                    returns: \(function.returnType!.dropLast()).self
                """
            }

            ")"
        }
        .public()
    }
}

@main
struct NodeMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NodeMethodGroupMacro.self,
    ]
}
