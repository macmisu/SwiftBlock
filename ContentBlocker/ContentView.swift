//
//  ContentView.swift
//  ContentBlocker
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import SwiftUI

struct ContentView : View {
    @ObservedObject private var lists: ListManager = ListManager()

    var body: some View {
        List {
            Text(lists.statusMessage)
            HStack {
                Spacer()
                Button(action: {
                    self.lists.updateAssetsList()
                }) {
                    Text(
                        self.lists.loadingAssetsList
                            ? "Loading..."
                            : self.lists.assetsNeedsUpdate
                                ? "⚠️ Update outdated assets list"
                                : "Update assets list"
                    )
                }

                Button(action: {
                    self.lists.updateAssets()
                }) {
                    Text("Update assets")
                }

                if lists.assets != nil {
                    Button(action: {
                        self.lists.genBlocklist()
                    }) {
                        Text("Generate Blocklist")
                    }
                } else {
                    EmptyView()
                }
                Spacer()
            }

            ForEach(lists.orderedAssets() ?? []) { asset in
                HStack {
                    Toggle(isOn: .constant(!asset.off)) {
                        Text(asset.title ?? "(error)")
                        Text(asset.id)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text((self.lists.assetLoadStates[asset.id] ?? .none).toLabel())
                }
            }
        }
    }
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
