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
                    communicator.terminate()
                    self.communicator = nil
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

                Button("Stress test") { // NOTE: the limit seems to be around 8000 bytes. I'm treating it as 4096 to be safe.
                    Task {
                        _ = try await communicator.notify(
                            method: .init(repeating: "G", count: 8168),
                            params: [:]
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
