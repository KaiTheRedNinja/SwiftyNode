//
//  ContentView.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 5/9/24.
//

import SwiftUI
import SwiftyNodeKit
import Log

import NodeMacro

@NodeMethodGroup
private protocol GithubAPI {
    func doSomething() async throws -> String?

    func listForOrg(org orgName: String) async throws -> [String]?
}

@NativeMethodGroup
protocol UserInfoAPI: NativeMethodGroupProtocol {
    func doSomething() async throws -> String?

    func listForOrg(org orgName: String) async throws -> [String]?
}

struct ContentView: View {
    @AppStorage("moduleLocation")
    var moduleLocation: String = ""
    @AppStorage("githubOrg")
    var githubOrg: String = ""

    @State var communicator: NodeCommunicator?
    @State var moduleOutput: String = ""

    init() {
    }

    var body: some View {
        VStack {
            TextField("Module location:", text: $moduleLocation)
            if let communicator {
                Button("Terminate") {
                    Task {
                        await communicator.terminate()
                        await moduleOutput = communicator.readConsole()
                        self.communicator = nil
                    }
                }
                TextField("Github org:", text: $githubOrg)

                HStack {
                    Button("Request") {
                        Task {
                            let result = try await communicator.request(
                                method: "githubListForOrg",
                                params: ["orgName": githubOrg],
                                returns: [String].self
                            )

                            moduleOutput = result?.joined(separator: "\n") ?? "something went wrong"
                        }
                    }

                    Button("Stress test") {
                        Task {
                            do {
                                for index in 0..<5 {
                                    _ = try await communicator.notify(
                                        method: "t\(index)",
                                        params: nil
                                    )
                                }
                                try await communicator.request(
                                    method: String(repeating: "t", count: 10_000),
                                    params: nil,
                                    returns: Void.self
                                )
                            } catch {
                                Log.error("STRESS TEST ERROR: \(error)")
                            }
                        }
                    }

                    Button("Echo") {
                        Task {
                            do {
                                try await communicator.request(
                                    method: "nodeEcho",
                                    params: ["test": 300],
                                    returns: Void.self
                                )
                            } catch {
                                Log.error("ECHO ERROR: \(error)")
                            }
                        }
                    }
                }
            } else {
                Button("Run module") {
                    Task {
                        guard let nodeRuntime = await NodeJS.builtin else {
                            moduleOutput = "No node runtime found"
                            return
                        }
                        let moduleURL = URL(filePath: moduleLocation)
                        moduleOutput = "Running \(moduleURL.standardizedFileURL.relativePath)"
                        let interface = await NodeInterface(nodeRuntime: nodeRuntime, moduleLocation: moduleURL)
                        do {
                            communicator = try await interface.runModule()
                            await communicator?.register(methodName: "swiftEcho") { params in
                                Log.info("Node echoed: \(params ?? [:])")
                                return "it was echoed :)"
                            }
                        } catch {
                            moduleOutput = "Module Error: \(error)"
                        }
                    }
                }
            }
            Text("Module output:")
            GroupBox {
                ScrollView {
                    Text(moduleOutput)
                }
            }
            .frame(maxHeight: 400)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
