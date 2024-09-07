// The Swift Programming Language
// https://docs.swift.org/swift-book

/// help me
@attached(peer, names: suffixed(MethodGroup))
public macro NodeMethodGroup() = #externalMacro(
    module: "NodeMacroMacros",
    type: "NodeMethodGroupMacro"
)
