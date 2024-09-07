import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

import Log
import SwiftyNodeKit

public struct NodeMethodGroupMacro: PeerMacro {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
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
                    let parameters = function.parameters.map { param in
                        let firstName = param.firstName.text
                        let secondName = if let second = param.secondName {
                            " " + second.text
                        } else {
                            ""
                        }
                        let type = param.type
                        return "\(firstName)\(secondName): \(type)"
                    }

                    let returnType = if let ret = function.returnType {
                        " -> \(ret)"
                    } else {
                        ""
                    }

                    Declaration(
                        "func \(function.name)(\(parameters.joined(separator: ", "))) async throws\(returnType)"
                    ) {
                        let functionToCall = if returnType.isEmpty { "notify" } else { "request "}

                        """
                        try await communicator.\(functionToCall)(
                            method: "\(function.name)",
                            params: \(parameters.isEmpty ? "nil\(returnType.isEmpty ? "" : ",")" : "[")
                        """

                        let paramCount = function.parameters.count
                        for (index, param) in function.parameters.enumerated() {
                            let trailingComma = if index < paramCount - 1 { "," } else { "" }
                            String(repeating: " ", count: 8)
                            + "\"\(param.firstName.text)\": \(param.secondName?.text ?? param.firstName.text)"
                            + trailingComma
                        }

                        if !parameters.isEmpty {
                            """
                                ],
                            """
                        }

                        if !returnType.isEmpty {
                            """
                                returns: \(function.returnType!.dropLast()).self
                            """
                        }

                        ")"
                    }
                }
            }
            .declSyntax()
        ]
    }
}

struct NodeMacroError: Error, CustomStringConvertible {
    var description: String

    private init(description: String) {
        self.description = description
    }

    static let notProtocol = NodeMacroError(
        description: "NodeMethodGroup must be attached to a Protocol."
    )
    static let notAsyncThrows = NodeMacroError(
        description: "Every function in the attached protocol must have `async throws`."
    )
    static let notOptional = NodeMacroError(
        description: "Every function's return type must be Void or an Optional."
    )
}

@main
struct NodeMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NodeMethodGroupMacro.self,
    ]
}
