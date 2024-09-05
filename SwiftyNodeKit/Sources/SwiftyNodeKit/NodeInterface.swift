//
//  NodeInterface.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

@NodeActor
public class NodeInterface {
    let nodeRuntime: NodeJS
    let moduleLocation: URL

    public init(nodeRuntime: NodeJS, moduleLocation: URL) {
        self.nodeRuntime = nodeRuntime
        self.moduleLocation = moduleLocation
    }

    public func runModule() -> String {
        nodeRuntime.execute(moduleLocation.appendingPathComponent("index.js"))
    }
}
