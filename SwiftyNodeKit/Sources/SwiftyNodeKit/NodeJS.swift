//
//  File.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

/// Class that manages access to the NodeJS runtime
@NodeActor
public class NodeJS {
    /// A `NodeJS` instance representing the builtin NodeJS runtime, if it exists.
    public static let builtin: NodeJS? = {
        let nodeString = shell("where node").trimmingCharacters(in: .whitespacesAndNewlines)
        guard nodeString.hasPrefix("/") && nodeString.hasSuffix("node") else {
            return nil
        }
        let nodeLocation = URL(fileURLWithPath: nodeString)
        return .init(nodeLocation: nodeLocation)
    }()

    /// The file URL of the NodeJS runtime
    public var nodeLocation: URL

    /// The path of the NodeJS runtime, as a string
    public var nodePath: String {
        nodeLocation.standardizedFileURL.relativePath
    }

    /// Creates a `NodeJS` instance referencing a node
    public init(nodeLocation: URL) {
        precondition(nodeLocation.isFileURL, "nodeLocation must be a file URL")
        self.nodeLocation = nodeLocation
    }

    /// Gets the version of the NodeJS runtime.
    ///
    /// Note that this value is NOT cached, and each call to this function requires a shell command and is therefore
    /// extremely expensive, time and resource wise.
    public func getNodeVersion() -> String {
        shell("\(nodePath) --version")
    }

    /// Uses the NodeJS runtime to execute a javascript file in a node project.
    public func execute(_ fileURL: URL) -> String {
        shell("\(nodePath) \(fileURL.standardizedFileURL.relativePath)")
    }
}

private func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["--login", "-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    task.launch()

    do {
        guard let data = try pipe.fileHandleForReading.readToEnd() else { return "" }
        let output = String(data: data, encoding: .utf8)!
        return output
    } catch {
        return "ERROR: \(error)"
    }
}
