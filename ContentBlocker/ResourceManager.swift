//
//  ResourceManager.swift
//  ContentBlocker
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation

class ResourceManager {

    static let appGroupID = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String + "net.cloudwithlightning.swiftblock"

    static var containerURL: URL {
        get {
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)!
        }
    }

    init() {
        try! FileManager.default.createDirectory(at: Self.containerURL.appendingPathComponent("resources"), withIntermediateDirectories: true, attributes: nil)
    }

    func urlForResource(named name: String) -> URL {
        return Self.containerURL.appendingPathComponent("resources").appendingPathComponent(name)
    }

    public func loadResource(named name: String) -> String? {
        let resourceURL = urlForResource(named: name)

        if let data = FileManager.default.contents(atPath: resourceURL.path) {
            return String(data: data, encoding: .utf8)!
        }
        return nil
    }

    public func storeResource(named name: String, with contents: String) {
        let resourceURL = urlForResource(named: name)

        FileManager.default.createFile(atPath: resourceURL.path, contents: contents.data(using: .utf8), attributes: [:])
    }

    public func clearBlocklists() {
        if let items = try? FileManager.default.contentsOfDirectory(atPath: Self.containerURL.path) {
            for item in items {
                if item.starts(with: "blocklist-") {
                    try? FileManager.default.removeItem(at: Self.containerURL.appendingPathComponent(item))
                }
            }
        }
    }

    public func storeBlocklist(_ data: Data, index: Int) {
        FileManager.default.createFile(atPath: Self.containerURL.appendingPathComponent("blocklist-\(index).json").path, contents: data, attributes: nil)
    }
}
