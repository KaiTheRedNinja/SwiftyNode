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
        description: "This macro must be attached to a Protocol."
    )
    static let notConform = NodeMacroError(
        description: "The attached protocol must conform to the NativeMethodGroupProtocol protocol."
    )
    static let notAsyncThrows = NodeMacroError(
        description: "Every function in the NodeMethodGroup's attached protocol must have `async throws`."
    )
    static let notOptional = NodeMacroError(
        description: "Every NodeMethodGroup function's return type must be Void or an Optional."
    )

    static func custom(_ description: String) -> Self {
        .init(description: description)
    }
}
