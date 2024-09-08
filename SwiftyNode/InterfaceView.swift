//
//  InterfaceView.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 7/9/24.
//

import SwiftUI
import SwiftyNodeKit

struct InterfaceView: View {
    @ObservedObject var nodeExt: NodeExtension

    var body: some View {
        VStack {
            Button("Terminate") {
                Task {
                    await nodeExt.terminate()
                }
            }

            HStack {
                ForEach(nodeExt.buttons, id: \.id) { button in
                    Button {
                        Task {
                            try await nodeExt.buttonsAPI.buttonPressed(id: button.id)
                        }
                    } label: {
                        Text(button.title)
                    }
                }
            }

            Text("Module output:")
            GroupBox {
                ScrollView {
                    Text(nodeExt.moduleOutput)
                }
            }
            .frame(maxHeight: 400)
        }
    }
}
