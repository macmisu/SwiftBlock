//
//  BlockListGenerator.swift
//  ContentBlocker
//
//  Created by cpsdqs on 2019-06-19.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation

func generateBlockList(_ list: BlockList) -> [BlockerDeclaration] {
    var decls: [BlockerDeclaration] = []

    for rule in list.rules {
        let trigger = ruleToTrigger(rule)

        if rule.negative {
            let action = BlockerAction(type: .ignorePreviousRules)

            decls.append(BlockerDeclaration(trigger: trigger, action: action))
        } else {
            var actionType: BlockerAction.ActionType = .block
            var actionSelector: String?
            if let selector = rule.selector {
                actionType = .cssDisplayNone
                if selector.starts(with: "+js(") {
                    // unsupported
                    continue
                }
                actionSelector = selector
            }
            let action = BlockerAction(type: actionType, selector: actionSelector)

            decls.append(BlockerDeclaration(trigger: trigger, action: action))
        }
    }

    return decls
}

func ruleToTrigger(_ rule: FilterRule) -> BlockerTrigger {
    let urlFilter: String
    var ifDomain: [String]?
    var unlessDomain: [String]?
    if rule.urls.count > 1 {
        // domain list
        urlFilter = ".*"

        ifDomain = []
        unlessDomain = []

        for url in rule.urls {
            switch url {
            case .match(let domain):
                ifDomain!.append(domain)
            case .notMatch(let domain):
                unlessDomain!.append(domain)
            }
        }
    } else if !rule.urls.isEmpty {
        switch rule.urls[0] {
        case .match(let s):
            if s.isEmpty {
                urlFilter = ".*"
            } else {
                urlFilter = s
            }
        case .notMatch(_):
            fatalError("single url filter is inverted")
        }
    } else {
        urlFilter = ".*"
    }

    var trigger = BlockerTrigger(urlFilter: urlFilter, ifDomain: ifDomain, unlessDomain: unlessDomain)

    if rule.options.matchCase {
        trigger.urlFilterIsCaseSensitive = true
    }

    var resourceTypes: [String] = []

    func addResourceType(key: String, value: Bool?) {
        if let value = value {
            if value {
                resourceTypes.append(key)
            } else {
                if resourceTypes.isEmpty {
                    resourceTypes.append(contentsOf: allResourceTypes)
                }
                resourceTypes.removeAll { $0 == key }
            }
        }
    }

    addResourceType(key: "script", value: rule.options.script)
    addResourceType(key: "image", value: rule.options.image)
    addResourceType(key: "style-sheet", value: rule.options.stylesheet)
    addResourceType(key: "document", value: rule.options.document)
    addResourceType(key: "popup", value: rule.options.popup)

    trigger.resourceType = resourceTypes.isEmpty ? nil : resourceTypes

    if let value = rule.options.thirdParty {
        if value {
            trigger.loadType = ["third-party"]
        } else {
            trigger.loadType = ["first-party"]
        }
    }

    for domain in rule.options.domains {
        switch domain {
        case .match(let domain):
            if trigger.ifDomain == nil {
                trigger.ifDomain = []
            }
            trigger.ifDomain!.append(domain)
        case .notMatch(let domain):
            if trigger.unlessDomain == nil {
                trigger.unlessDomain = []
            }
            trigger.unlessDomain!.append(domain)
        }
    }

    if trigger.ifDomain?.isEmpty ?? false {
        trigger.ifDomain = nil
    }
    if trigger.unlessDomain?.isEmpty ?? false {
        trigger.unlessDomain = nil
    }

    if !(trigger.ifDomain?.isEmpty ?? true) && !(trigger.unlessDomain?.isEmpty ?? true) {
        trigger.unlessDomain = nil
    }

    return trigger
}

let allResourceTypes = ["document", "image", "style-sheet", "script", "font", "raw", "svg-document", "media" ,"popup"]

struct BlockerDeclaration: Codable {
    var trigger: BlockerTrigger
    var action: BlockerAction
}

struct BlockerTrigger: Codable {
    var urlFilter: String
    var urlFilterIsCaseSensitive: Bool?
    var ifDomain: [String]?
    var unlessDomain: [String]?
    var resourceType: [String]?
    var loadType: [String]?
    var ifTopURL: [String]?
    var unlessTopURL: [String]?

    private enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
        case urlFilterIsCaseSensitive = "url-filter-is-case-sensitive"
        case ifDomain = "if-domain"
        case unlessDomain = "unless-domain"
        case resourceType = "resource-type"
        case loadType = "load-type"
        case ifTopURL = "if-top-url"
        case unlessTopURL = "unless-top-url"
    }
}

struct BlockerAction: Codable {
    var type: ActionType
    var selector: String?

    enum ActionType: Codable {
        case block
        case blockCookies
        case cssDisplayNone
        case ignorePreviousRules
        case makeHttps

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try container.decode(String.self) {
            case "block": self = .block
            case "block-cookies": self = .blockCookies
            case "css-display-none": self = .cssDisplayNone
            case "ignore-previous-rules": self = .ignorePreviousRules
            case "make-https": self = .makeHttps
            default: throw DecodingError.invalid
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .block: try container.encode("block")
            case .blockCookies: try container.encode("block-cookies")
            case .cssDisplayNone: try container.encode("css-display-none")
            case .ignorePreviousRules: try container.encode("ignore-previous-rules")
            case .makeHttps: try container.encode("make-https")
            }
        }

        enum DecodingError: Error {
            case invalid
        }
    }
}
