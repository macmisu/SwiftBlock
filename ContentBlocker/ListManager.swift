//
//  ListManager.swift
//  ContentBlocker
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation
import Alamofire
import SwiftUI
import Combine
import SafariServices

let ASSETS_JSON = "assets.json"

class ListManager : ObservableObject {
    static let assetsListURL = "https://raw.githubusercontent.com/gorhill/uBlock/master/assets/assets.json"

    let resources = ResourceManager()
    let afSession = SessionManager()

    @Published var assets: [String:Asset]?
    @Published var loadingAssetsList = false
    @Published var assetsNeedsUpdate = false
    @Published var statusMessage = ""
    @Published var assetLoadStates: [String:AssetLoadState] = [:]

    init() {
        loadAssets()
    }

    func loadAssets() {
        if let data = resources.loadResource(named: "assets") {
            if let data = try? JSONDecoder().decode([String:Asset].self, from: data.data(using: .utf8)!) {
                assetsNeedsUpdate = data[ASSETS_JSON]?.needsUpdate() ?? true
                assets = data

                for (id, asset) in assets! {
                    let exists = resources.loadResource(named: id) != nil
                    let outdated = asset.needsUpdate()
                    assetLoadStates[id] = exists ? (outdated ? .outdated : .loaded) : AssetLoadState.none
                }
            }
        }
    }

    public func updateAssets() {
        if let assets = assets {
            for (name, asset) in assets {
                loadAsset(named: name, asset)
            }
        }
    }

    func orderedAssets() -> [Asset]? {
        if let assets = assets {
            return assets.keys.sorted().map { assets[$0]! }.filter { !$0.isInternal }
        }
        return nil
    }

    func genBlocklist() {
        var declarations: [BlockerDeclaration] = []

        if let assets = assets {
            for (name, asset) in assets {
                if asset.isInternal {
                    continue
                }
                if name == "plowe-0" { // TODO: unsupported hosts format
                    continue
                }
                if !asset.off {
                    if let resource = resources.loadResource(named: name) {
                        debugPrint("Adding \(name) to blocklist")
                        let blocklist = parseBlockList(resource)
                        declarations.append(contentsOf: generateBlockList(blocklist))
                    }
                }
            }
        }

        var decls: [[BlockerDeclaration]] = [[]]
        for decl in declarations {
            if decls.last!.count == 50000 {
                decls.append([decl])
            } else {
                // idk
                var last = decls.popLast()!
                last.append(decl)
                decls.append(last)
            }
        }

        for (i, list) in decls.enumerated() {
            let data = try! JSONEncoder().encode(list)
            resources.storeBlocklist(data, index: i)
        }

        statusMessage = "Generated blocklist"

        SFContentBlockerManager.reloadContentBlocker(withIdentifier: "net.cloudwithlightning.SwiftBlock.Blocker", completionHandler: { error in
            if let error = error {
                NSLog("Failed to reload content blocker: \(error.localizedDescription)")
            }
        })
    }

    func loadAsset(named name: String, _ asset: Asset) {
        assetLoadStates[name] = .loading

        NSLog("Loading asset \(name)")
        if asset.contentURL.isEmpty {
            NSLog("no content URL, aborting")
            return
        }
        afSession.request(URL(string: asset.contentURL[0])!).responseData { response in
            if let error = response.error {
                NSLog("Failed to download asset \(name): \(error.localizedDescription)")
                self.assetLoadStates[name] = .error("Download failed")
            } else if let data = response.result.value {
                NSLog("Loaded asset \(name)")
                self.resources.storeResource(named: name, with: String(data: data, encoding: .utf8)!)
                self.assetLoadStates[name] = .loaded
            }
        }
    }

    func updateAssetsList() {
        loadingAssetsList = true

        NSLog("updating assets")
        afSession.request(URL(string: Self.assetsListURL)!).responseJSON { response in
            self.loadingAssetsList = false
            if let error = response.error {
                NSLog("Failed to download assets because of an error \(error.localizedDescription)")
                self.statusMessage = "Failed to download assets list"
            } else if let data = response.result.value as? [String: [String: Any]] {
                NSLog("Loaded assets.json")

                let assets: [String:Asset] = data.mapValues({ data -> Asset in
                    let asset = Asset()

                    if let content = data["content"] as? String {
                        asset.isInternal = content == "internal"
                    }
                    if let group = data["group"] as? String {
                        asset.group = group
                    }
                    if let updateAfter = data["updateAfter"] as? Int {
                        asset.updateAfter = updateAfter
                    }
                    if let contentURL = data["contentURL"] as? String {
                        asset.contentURL = [contentURL]
                    } else if let contentURL = data["contentURL"] as? [String] {
                        asset.contentURL = contentURL
                    }
                    if let title = data["title"] as? String {
                        asset.title = title
                    }
                    if let supportURL = data["supportURL"] as? String {
                        asset.supportURL = supportURL
                    }
                    if let instructionURL = data["instructionURL"] as? String {
                        asset.instructionURL = instructionURL
                    }
                    if let off = data["off"] as? Bool {
                        asset.off = off
                    }
                    if let lang = data["lang"] as? String {
                        asset.lang = lang
                    }
                    return asset
                })
                for (id, asset) in assets {
                    asset.id = id
                }
                self.resources.storeResource(named: "assets", with: String(data: try! JSONEncoder().encode(assets), encoding: .utf8)!)
                self.statusMessage = "Successfully loaded assets list"
                self.loadAssets()
            } else {
                NSLog("Failed to read assets.json; valid JSON but unrecognized format")
                self.statusMessage = "Unexpected assets list format"
            }
        }
    }
}

class Asset: Codable, Identifiable {
    var id: String = ""
    var isInternal: Bool = false
    var group: String = ""
    var updated: Date = Date()
    var updateAfter: Int = 4
    var contentURL: [String] = []
    var title: String?
    var supportURL: String?
    var instructionURL: String?
    var off: Bool = false
    var lang: String?

    func needsUpdate() -> Bool {
        return -updated.timeIntervalSinceNow > Double(updateAfter) * 86400.0
    }
}

enum AssetLoadState {
    case none
    case outdated
    case loading
    case error(String)
    case loaded

    func toLabel() -> String {
        switch (self) {
        case .none: return "N/A"
        case .outdated: return "Outdated"
        case .loading: return "Loading"
        case .error(let err): return err
        case .loaded: return "✓"
        }
    }
}
