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
        let nodeString = try? shellAndWait("where node").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let nodeString, nodeString.hasPrefix("/") && nodeString.hasSuffix("node") else {
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
        (try? shellAndWait("\(nodePath) --version")) ?? "Could not obtain version"
    }

    /// Uses the NodeJS runtime to execute a javascript file in a node project.
    ///
    /// This function is a suspending function that waits until node has exited, then returns a string. If the file
    /// never exits, this function will not exit and will cause the caller to hang.
    public func execute(_ fileURL: URL, args: [String] = []) throws -> String {
        var command = "\(nodePath) \(fileURL.standardizedFileURL.relativePath)"
        if !args.isEmpty {
            command += " "
            command += args.joined(separator: " ")
        }
        return try shellAndWait(command)
    }

    /// Uses the NodeJS runtime to run a javascript file in a node project.
    ///
    /// This function is not a suspending function. It will start the node process, then return an object that allows
    /// the caller to manage it.
    public func run(_ fileURL: URL, args: [String] = []) throws -> NodeProcess {
        var command = "\(nodePath) \(fileURL.standardizedFileURL.relativePath)"
        if !args.isEmpty {
            command += " "
            command += args.joined(separator: " ")
        }
        let (process, pipe) = try shell(command)
        return .init(process: process, pipe: pipe)
    }
}

/// An object wrapping a `Process`, representing a NodeJS process
public class NodeProcess {
    var process: Process
    var pipe: Pipe

    init(process: Process, pipe: Pipe) {
        self.process = process
        self.pipe = pipe
    }
}

private func shell(_ command: String) throws -> (Process, Pipe) {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["--login", "-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    try task.run()

    return (task, pipe)
}

private func shellAndWait(_ command: String) throws -> String {
    let (process, pipe) = try shell(command)
    process.waitUntilExit()

    do {
        guard let data = try pipe.fileHandleForReading.readToEnd() else { return "" }
        let output = String(data: data, encoding: .utf8)!
        return output
    } catch {
        return "ERROR: \(error)"
    }
}
