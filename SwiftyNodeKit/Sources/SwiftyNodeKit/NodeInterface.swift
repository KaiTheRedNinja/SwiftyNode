//
//  NodeInterface.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

/// An interface to run scripts with NodeJS
@NodeActor
public class NodeInterface {
    /// The NodeJS runtime
    let nodeRuntime: NodeJS
    /// The location of the module that this `NodeInterface` is running. This should be a directory.
    let moduleLocation: URL

    /// Creates a `NodeInterface` from a node runtime and the location of the module to run
    public init(nodeRuntime: NodeJS, moduleLocation: URL) {
        self.nodeRuntime = nodeRuntime
        self.moduleLocation = moduleLocation
    }

    /// Runs the module using `node [path here]`. By default, it executes `index.js` file within
    /// the ``moduleLocation``, but it can be changed.
    public func runModule(targetFile: String = "index.js") -> String {
        nodeRuntime.execute(moduleLocation.appendingPathComponent(targetFile))
    }
}
