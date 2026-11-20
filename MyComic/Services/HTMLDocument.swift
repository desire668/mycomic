//
//  HTMLDocument.swift
//  MyComic
//
//  A small, dependency-free HTML tokenizer and DOM used to parse the pages of
//  mycomic.com. It is intentionally tolerant: unknown or malformed markup never
//  throws, it simply produces a best-effort tree.
//
//  Only the subset needed by the site is supported: tags, attributes, text,
//  comments, doctype, raw-text elements (script/style).
//

import Foundation

final class HTMLNode {
    static let textTag = "#text"

    let tag: String
    let attributes: [String: String]
    let textValue: String
    private(set) var children: [HTMLNode] = []
    weak var parent: HTMLNode?

    private var cachedText: String?

    init(tag: String, attributes: [String: String] = [:], text: String = "") {
        self.tag = tag
        self.attributes = attributes
        self.textValue = text
    }

    var isText: Bool { tag == HTMLNode.textTag }

    func append(_ child: HTMLNode) {
        child.parent = self
        children.append(child)
    }

    func attribute(_ name: String) -> String? {
        attributes[name.lowercased()]
    }

    var classNames: [String] {
        (attribute("class") ?? "").split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
    }

    func hasClass(_ name: String) -> Bool {
        classNames.contains(name)
    }

    /// All descendant elements (excluding text nodes) in document order.
    /// Uses an explicit stack so deep pages cannot overflow the call stack.
    var elementDescendants: [HTMLNode] {
        var result: [HTMLNode] = []
        var stack: [HTMLNode] = Array(children.reversed())
        while let node = stack.popLast() {
            if node.isText { continue }
            result.append(node)
            for child in node.children.reversed() {
                stack.append(child)
            }
        }
        return result
    }

    func queryAll(_ predicate: (HTMLNode) -> Bool) -> [HTMLNode] {
        elementDescendants.filter(predicate)
    }

    func queryFirst(_ predicate: (HTMLNode) -> Bool) -> HTMLNode? {
        elementDescendants.first(where: predicate)
    }

    func elements(tag: String) -> [HTMLNode] {
        queryAll { $0.tag == tag }
    }

    func firstElement(tag: String) -> HTMLNode? {
        queryFirst { $0.tag == tag }
    }

    func firstDescendant(withClass name: String) -> HTMLNode? {
        queryFirst { $0.hasClass(name) }
    }

    /// Visible text of this subtree with whitespace collapsed.
    var textContent: String {
        if let cachedText = cachedText { return cachedText }
        var buffer = ""
        collectText(into: &buffer)
        let collapsed = buffer
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        cachedText = collapsed
        return collapsed
    }

    private func collectText(into buffer: inout String) {
        if isText {
            buffer += textValue
            return
        }
        if tag == "script" || tag == "style" { return }
        for child in children {
            child.collectText(into: &buffer)
        }
    }
}

// MARK: - Document

struct HTMLDocument {
    let root: HTMLNode

    init(html: String) {
        root = HTMLParser(html: html).parse()
    }

    func meta(_ key: String) -> String? {
        let node = root.queryFirst { node in
            guard node.tag == "meta" else { return false }
            let property = node.attribute("property")?.lowercased()
            let name = node.attribute("name")?.lowercased()
            return property == key.lowercased() || name == key.lowercased()
        }
        let content = node?.attribute("content")?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (content?.isEmpty == false) ? content : nil
    }

    func elements(tag: String) -> [HTMLNode] { root.elements(tag: tag) }

    func queryAll(_ predicate: (HTMLNode) -> Bool) -> [HTMLNode] { root.queryAll(predicate) }
}

// MARK: - Parser

private struct HTMLParser {
    private let bytes: [UInt8]
    private var index: Int = 0

    private static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    init(html: String) {
        bytes = Array(html.utf8)
    }

    mutating func parse() -> HTMLNode {
        let root = HTMLNode(tag: "#document")
        var stack: [HTMLNode] = [root]
        var textBytes: [UInt8] = []

        func flushText() {
            guard !textBytes.isEmpty else { return }
            let raw = String(decoding: textBytes, as: UTF8.self)
            textBytes.removeAll(keepingCapacity: true)
            let decoded = HTMLEntities.decode(raw)
            if !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stack.last?.append(HTMLNode(tag: HTMLNode.textTag, text: decoded))
            }
        }

        while index < bytes.count {
            let byte = bytes[index]

            if byte == 0x3C { // '<'
                if index + 3 < bytes.count, bytes[index + 1] == 0x21, bytes[index + 2] == 0x2D, bytes[index + 3] == 0x2D {
                    // Comment
                    flushText()
                    index = index + 4
                    while index + 2 < bytes.count {
                        if bytes[index] == 0x2D, bytes[index + 1] == 0x2D, bytes[index + 2] == 0x3E {
                            index += 3
                            break
                        }
                        index += 1
                    }
                    continue
                }

                if index + 1 < bytes.count, bytes[index + 1] == 0x21 || bytes[index + 1] == 0x3F {
                    // Doctype or processing instruction
                    flushText()
                    while index < bytes.count, bytes[index] != 0x3E { index += 1 }
                    index += 1
                    continue
                }

                if index + 1 < bytes.count, bytes[index + 1] == 0x2F { // '</'
                    flushText()
                    index += 2
                    let name = readTagName()
                    while index < bytes.count, bytes[index] != 0x3E { index += 1 }
                    index += 1
                    closeTag(name, stack: &stack)
                    continue
                }

                if index + 1 < bytes.count, isNameStart(bytes[index + 1]) {
                    flushText()
                    index += 1
                    let name = readTagName()
                    let (attributes, selfClosing) = readAttributes()
                    let node = HTMLNode(tag: name, attributes: attributes)
                    stack.last?.append(node)

                    if name == "script" || name == "style" {
                        skipRawText(until: name)
                    }

                    if !selfClosing && !HTMLParser.voidTags.contains(name) {
                        stack.append(node)
                    }
                    continue
                }
            }

            textBytes.append(byte)
            index += 1
        }

        flushText()
        return root
    }

    private func isNameStart(_ byte: UInt8) -> Bool {
        (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }

    private func isNameChar(_ byte: UInt8) -> Bool {
        isNameStart(byte) || (byte >= 0x30 && byte <= 0x39) || byte == 0x2D || byte == 0x3A || byte == 0x5F
    }

    private mutating func readTagName() -> String {
        let start = index
        while index < bytes.count, isNameChar(bytes[index]) { index += 1 }
        return String(decoding: bytes[start..<index], as: UTF8.self).lowercased()
    }

    /// Parses attributes until '>'. Returns attributes and whether the tag was
    /// self-closing.
    private mutating func readAttributes() -> ([String: String], Bool) {
        var attributes: [String: String] = [:]
        var selfClosing = false

        while index < bytes.count {
            skipWhitespace()
            guard index < bytes.count else { break }

            if bytes[index] == 0x3E { // '>'
                index += 1
                break
            }
            if bytes[index] == 0x2F { // '/'
                selfClosing = true
                index += 1
                continue
            }

            let nameStart = index
            while index < bytes.count {
                let byte = bytes[index]
                if byte == 0x3D || byte == 0x3E || byte == 0x2F || byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
                    break
                }
                index += 1
            }
            let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
            skipWhitespace()

            var value = ""
            if index < bytes.count, bytes[index] == 0x3D { // '='
                index += 1
                skipWhitespace()
                if index < bytes.count, bytes[index] == 0x22 || bytes[index] == 0x27 { // quote
                    let quote = bytes[index]
                    index += 1
                    let valueStart = index
                    while index < bytes.count, bytes[index] != quote { index += 1 }
                    value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
                    if index < bytes.count { index += 1 }
                } else {
                    let valueStart = index
                    while index < bytes.count, bytes[index] != 0x3E, bytes[index] != 0x20, bytes[index] != 0x0A, bytes[index] != 0x09 {
                        index += 1
                    }
                    value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
                }
            }

            if !name.isEmpty {
                attributes[name] = HTMLEntities.decode(value)
            }
        }

        return (attributes, selfClosing)
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
                index += 1
            } else {
                break
            }
        }
    }

    /// Skips the content of script/style elements up to the closing tag.
    private mutating func skipRawText(until tag: String) {
        let closing = "</" + tag
        let closingBytes = Array(closing.utf8)
        while index + closingBytes.count <= bytes.count {
            var matched = true
            for offset in 0..<closingBytes.count where bytes[index + offset] != closingBytes[offset] {
                matched = false
                break
            }
            if matched { return }
            index += 1
        }
        index = bytes.count
    }

    private func closeTag(_ name: String, stack: inout [HTMLNode]) {
        guard !name.isEmpty else { return }
        if let position = stack.lastIndex(where: { $0.tag == name }), position > 0 {
            stack.removeSubrange(position...)
        }
    }
}

// MARK: - Entities

enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "mdash": "—", "ndash": "–", "hellip": "…",
        "laquo": "«", "raquo": "»", "times": "×", "middot": "·",
        "copy": "©", "reg": "®", "deg": "°", "plusmn": "±",
        "euro": "€", "pound": "£", "yen": "¥", "sect": "§", "para": "¶",
        "bull": "•", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "shy": "\u{00AD}", "frac12": "½", "sup2": "²", "sup3": "³"
    ]

    static func decode(_ string: String) -> String {
        guard string.contains("&") else { return string }
        let characters = Array(string)
        var result = ""
        result.reserveCapacity(string.count)

        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character != "&" {
                result.append(character)
                index += 1
                continue
            }

            // Find the terminating semicolon within a sane distance.
            var end = index + 1
            let limit = min(characters.count, index + 12)
            var found = false
            while end < limit {
                if characters[end] == ";" {
                    found = true
                    break
                }
                end += 1
            }

            if found {
                let body = String(characters[(index + 1)..<end])
                if let decoded = decodeEntityBody(body) {
                    result.append(decoded)
                    index = end + 1
                    continue
                }
            }

            result.append("&")
            index += 1
        }

        return result
    }

    private static func decodeEntityBody(_ body: String) -> String? {
        if body.hasPrefix("#") {
            let numberPart = String(body.dropFirst())
            let value: UInt32?
            if numberPart.hasPrefix("x") || numberPart.hasPrefix("X") {
                value = UInt32(numberPart.dropFirst(), radix: 16)
            } else {
                value = UInt32(numberPart, radix: 10)
            }
            if let value = value, let scalar = Unicode.Scalar(value) {
                return String(scalar)
            }
            return nil
        }
        return named[body.lowercased()]
    }
}
