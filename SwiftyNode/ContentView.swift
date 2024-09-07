//
//  ContentView.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 5/9/24.
//

import SwiftUI
import SwiftyNodeKit

struct ContentView: View {
    @AppStorage("moduleLocation") var moduleLocation: String = ""
    @AppStorage("githubOrg") var githubOrg: String = ""
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
                Button("Request") {
                    Task {
                        let result = try await communicator.request(
                            method: "githubListForOrg",
                            params: ["orgName": githubOrg],
                            returns: Any.self
                        )

                        guard let result = result as? [String] else {
                            return
                        }

                        moduleOutput = result.joined(separator: "\n")
                    }
                }

                Button("Stress test") { // NOTE: the limit seems to be around 8192 bytes. I'm treating it as 4096 to be safe.
                    Task {
                        for i in 0..<5 {
                            _ = try await communicator.notify(
                                method: "t\(i)",
                                params: nil
                            )
                        }
                        try await communicator.notify(
                            method: String(repeating: "t", count: 10_000),
                            params: nil
                        )
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
