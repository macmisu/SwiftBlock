//
//  ContentBlockerRequestHandler.swift
//  Blocker
//
//  Created by cpsdqs on 2019-06-20.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    static let appGroupID = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String + "net.cloudwithlightning.swiftblock"

    static var containerURL: URL {
        get {
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)!
        }
    }

    func beginRequest(with context: NSExtensionContext) {
        let item = NSExtensionItem()
        item.attachments = []

        let files = try! FileManager.default.contentsOfDirectory(atPath: Self.containerURL.path)
        for file in files {
            if file.starts(with: "blocklist-") {
                let attachment = NSItemProvider(contentsOf: Self.containerURL.appendingPathComponent(file))!
                item.attachments?.append(attachment)
            }
        }
        
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
