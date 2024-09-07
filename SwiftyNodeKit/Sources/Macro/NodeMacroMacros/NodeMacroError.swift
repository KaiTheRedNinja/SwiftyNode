//
//  NodeMacroError.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 7/9/24.
//

import Foundation

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
