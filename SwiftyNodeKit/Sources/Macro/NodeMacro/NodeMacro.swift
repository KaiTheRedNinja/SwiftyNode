// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftyNodeKit

/// help me
@attached(peer, names: suffixed(MethodGroup))
public macro NodeMethodGroup() = #externalMacro(
    module: "NodeMacroMacros",
    type: "NodeMethodGroupMacro"
)

@attached(extension, conformances: NativeMethodGroupProtocol, names: named(registerWithCommunicator))
public macro NativeMethodGroup() = #externalMacro(
    module: "NodeMacroMacros",
    type: "NativeMethodGroupMacro"
)
