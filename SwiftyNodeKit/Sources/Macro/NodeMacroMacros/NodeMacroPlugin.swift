//
//  NodeMacroPlugin.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 7/9/24.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct NodeMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NodeMethodGroupMacro.self,
        NativeMethodGroupMacro.self
    ]
}
