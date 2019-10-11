//
//  BlockListParser.swift
//  ContentBlocker
//
//  Created by cpsdqs on 2019-06-19.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation

func parseBlockList(_ source: String) -> BlockList {
    var rules: [FilterRule] = []

    source.enumerateLines { line, _ in
        if line.starts(with: "!") || line.isEmpty {
            // comment line
            return
        }

        if line.contains("#@#") {
            // no idea what this means
            return
        }

        if line.starts(with: "@@") {
            if var filter = FilterRule.parse(line: String(line[line.index(line.startIndex, offsetBy: 2)...])) {
                filter.negative = true
                rules.append(filter)
            }
        } else {
            if let filter = FilterRule.parse(line: String(line)) {
                rules.append(filter)
            }
        }
    }

    return BlockList(rules: rules)
}

struct BlockList: Codable {
    var rules: [FilterRule]
}

enum Match: Codable, Equatable {
    case match(String)
    case notMatch(String)

    enum CodingKeys: String, CodingKey {
        case match
        case content
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let match = try values.decode(Bool.self, forKey: .match)
        let content = try values.decode(String.self, forKey: .content)

        if match {
            self = .match(content)
        } else {
            self = .notMatch(content)
        }
    }

    var isMatch: Bool {
        get {
            switch self {
            case .match(_): return true
            default: return false
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .match(let content):
            try values.encode(true, forKey: .match)
            try values.encode(content, forKey: .content)
        case .notMatch(let content):
            try values.encode(false, forKey: .match)
            try values.encode(content, forKey: .content)
        }
    }
}

struct FilterOptions: Codable {
    var script: Bool?
    var image: Bool?
    var stylesheet: Bool?
    var object: Bool?
    var xmlhttprequest: Bool?
    var subdocument: Bool?
    var ping: Bool?
    var websocket: Bool?
    var webrtc: Bool?
    var document: Bool?
    var elemhide: Bool?
    var generichide: Bool?
    var genericblock: Bool?
    var popup: Bool?
    var other: Bool?

    var thirdParty: Bool?
    var domains: [Match] = []
    var sitekeys: String?
    var csp: String?
    var matchCase = false

}

/// A filter rule.
///
/// # Notes
/// - selectors may be formatted like `+js(script-name.js)` to target a script or something, not sure what it means
struct FilterRule: Codable {
    var urls: [Match]
    var selector: String?
    var options: FilterOptions
    var negative = false

    static func parse(line: String) -> FilterRule? {
        let anchorStart = line.starts(with: "|")
        let anchorProtocolOrWWW = line.starts(with: "||")
        let optionsIndex = line.lastIndex(of: "$") ?? line.endIndex

        let startIndexOffset = anchorProtocolOrWWW ? 2 : anchorStart ? 1 : 0
        let startIndex = line.index(line.startIndex, offsetBy: startIndexOffset)

        let mainPart = String(line[startIndex..<optionsIndex])
        let selectorIndex = firstIndexOfSubstring(in: mainPart, of: "##") ?? mainPart.endIndex
        var urlPart = String(mainPart[..<selectorIndex])

        let isRegExp = mainPart.starts(with: "/") && stringEndsWith(mainPart, with: "/")

        let anchorEnd = !isRegExp && stringEndsWith(urlPart, with: "|")

        if anchorEnd || isRegExp {
            // remove trailing | or /
            urlPart.removeLast()
        }

        for c in urlPart {
            if !c.isASCII {
                NSLog("Skipping rule \(line) because it contains unicode in the URL part and Safari doesn’t like that apparently")
                // Safari does not like rules like ||rołex.com^$document at all
                return nil
            }
        }

        let selector = selectorIndex < mainPart.endIndex
            && mainPart.index(selectorIndex, offsetBy: 1) < mainPart.endIndex
            && mainPart.index(selectorIndex, offsetBy: 2) < mainPart.endIndex
            ? String(mainPart[mainPart.index(selectorIndex, offsetBy: 2)...])
            : nil

        let options = optionsIndex < line.endIndex
            && line.index(optionsIndex, offsetBy: 1) < line.endIndex
            ? line[line.index(optionsIndex, offsetBy: 1)...]
            : nil

        var urlRegExp: [Match] = []
        if isRegExp {
            // regex filter
            urlRegExp.append(.match(urlPart))
            // actually unsupported
            return nil
        } else if selector != nil {
            // domains only, but comma-separated
            let domains = urlPart.split(separator: ",")
            // (this won’t actually check if these are domains only)
            if domains.count == 1 {
                urlRegExp.append(.match(pseudoGlobToRegex(urlPart)))
            } else {
                for domain in domains {
                    if domain.starts(with: "~") {
                        var d = String(domain)
                        d.removeFirst()
                        urlRegExp.append(.notMatch(d))
                    } else {
                        urlRegExp.append(.match(String(domain)))
                    }
                }
            }
        } else {
            // pseudo-glob
            var regex = pseudoGlobToRegex(urlPart)

            if anchorProtocolOrWWW {
                // anchors are not supported :(
                regex = "^https?:\\/\\/(www\\.)?" + regex
            } else if anchorStart {
                regex = "^" + regex
            }
            if anchorEnd {
                regex += "$"
            }

            urlRegExp.append(.match(regex))
        }

        var opts = FilterOptions()

        if let options = options {
            for option in options.split(separator: ",") {
                var opt = option
                var val = true
                if opt.starts(with: "~") {
                    opt.removeFirst()
                    val = false
                }
                switch opt {
                case "script": opts.script = val
                case "image": opts.image = val
                case "stylesheet": opts.stylesheet = val
                case "object": opts.object = val
                case "xmlhttprequest": opts.xmlhttprequest = val
                case "subdocument": opts.subdocument = val
                case "ping": opts.ping = val
                case "websocket": opts.websocket = val
                case "webrtc": opts.webrtc = val
                case "document": opts.document = val
                case "elemhide": opts.elemhide = val
                case "generichide": opts.generichide = val
                case "genericblock": opts.genericblock = val
                case "popup": opts.popup = val
                case "other": opts.other = val
                case "third-party": opts.thirdParty = val
                default:
                    if option == "match-case" {
                        opts.matchCase = true
                    } else if option.starts(with: "domain=") {
                        for domain in String(option)["domain=".endIndex...].split(separator: "|") {
                            if domain.starts(with: "~") {
                                var d = String(domain)
                                d.removeFirst()
                                opts.domains.append(.notMatch(d))
                            } else {
                                opts.domains.append(.match(String(domain)))
                            }
                        }
                    } else if option.starts(with: "sitekey=") {
                        opts.sitekeys = String(String(option)["sitekey=".endIndex...])
                    } else if option.starts(with: "csp=") {
                        opts.csp = String(String(option)["csp=".endIndex...])
                    }
                }
            }
        }

        return FilterRule(urls: urlRegExp, selector: selector, options: opts)
    }
}

func firstIndexOfSubstring(in string: String, of substring: String) -> String.Index? {
    var remaining = string
    var index = remaining.firstIndex(of: substring[substring.startIndex]) ?? remaining.endIndex
    while index < remaining.endIndex {
        if remaining[index...].starts(with: substring) {
            return index
        }
        remaining = String(remaining[remaining.index(index, offsetBy: 1)...])
        index = remaining.firstIndex(of: substring[substring.startIndex]) ?? remaining.endIndex
    }
    return nil
}

func stringEndsWith(_ string: String, with seq: String) -> Bool {
    var remaining = string
    var rseq = seq
    while !rseq.isEmpty && !remaining.isEmpty {
        let c = rseq.removeLast()
        if remaining.removeLast() != c {
            return false
        }
    }
    return rseq.isEmpty
}

func pseudoGlobToRegex(_ string: String) -> String {
    var regex = ""

    var index = string.startIndex
    while index < string.endIndex {
        let c = string[index]
        switch c {
        case "*": regex += ".*"
        case "^":
            // technically this should also allow $ but since $ isn’t allowed here’s a small
            // “close enough” hack
            // regex += "[^\\w_\\-.%]"
            regex += "[\\\\\\/&=!@#^*$:;,.<>?]" // close enough
            if string.index(index, offsetBy: 1) == string.endIndex {
                // last char, make separator optional to fake-match $
                regex += "?"
            }
        case ".": regex += "\\."
        case "[": regex += "\\["
        case "(": regex += "\\("
        case "{": regex += "\\{"
        case "+": regex += "\\+"
        case "$": regex += "\\$"
        case "\\": regex += "\\\\"
        case "?": regex += "\\?"
        case "|": regex += "\\|"
        default: regex.append(c)
        }

        index = string.index(index, offsetBy: 1)
    }

    return regex
}
