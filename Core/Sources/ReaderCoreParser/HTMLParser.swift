import Foundation
import ReaderCoreModels

/// HTML解析器，用于将HTML字符串解析为CSSNode树
public final class HTMLParser: Sendable {
    public init() {}
    
    /// 解析HTML字符串为CSSNode树
    public func parse(_ html: String) throws -> CSSNode {
        let scanner = Scanner(string: html)
        scanner.charactersToBeSkipped = nil
        
        var nodes: [CSSNode] = []
        var currentText = ""
        
        while !scanner.isAtEnd {
            if let text = scanUpToLessThan(scanner) {
                currentText += text
            }
            
            if scanner.isAtEnd {
                break
            }
            
            scanner.scanCharacter()
            
            if scanner.scanString("!--") != nil {
                if !currentText.isEmpty {
                    nodes.append(createTextNode(currentText))
                    currentText = ""
                }
                if let comment = scanComment(scanner) {
                    nodes.append(comment)
                }
            } else if scanner.scanString("/") != nil {
                if !currentText.isEmpty {
                    nodes.append(createTextNode(currentText))
                    currentText = ""
                }
                scanClosingTag(scanner)
            } else {
                if !currentText.isEmpty {
                    nodes.append(createTextNode(currentText))
                    currentText = ""
                }
                if let element = scanElement(scanner) {
                    nodes.append(element)
                }
            }
        }
        
        if !currentText.isEmpty {
            nodes.append(createTextNode(currentText))
        }
        
        return CSSNode(
            type: .document,
            children: nodes
        )
    }
    
    private func scanUpToLessThan(_ scanner: Scanner) -> String? {
        return scanner.scanUpToString("<")
    }
    
    private func scanComment(_ scanner: Scanner) -> CSSNode? {
        guard let content = scanner.scanUpToString("-->") else {
            return nil
        }
        scanner.scanString("-->")
        return CSSNode(
            type: .comment,
            textContent: content
        )
    }
    
    private func scanClosingTag(_ scanner: Scanner) {
        _ = scanner.scanUpToString(">")
        _ = scanner.scanCharacter()
    }
    
    private func scanElement(_ scanner: Scanner) -> CSSNode? {
        guard let tagName = scanTagName(scanner) else {
            return nil
        }
        
        let attributes = scanAttributes(scanner)
        
        if scanner.scanString("/>") != nil {
            return CSSNode(
                type: .element,
                tagName: tagName.lowercased(),
                attributes: attributes
            )
        }
        
        scanner.scanString(">")
        
        var children: [CSSNode] = []
        var currentText = ""
        
        while !scanner.isAtEnd {
            if let text = scanUpToLessThan(scanner) {
                currentText += text
            }
            
            if scanner.isAtEnd {
                break
            }
            
            scanner.scanCharacter()
            
            if scanner.scanString("/") != nil {
                if let closeTag = scanTagName(scanner), closeTag.lowercased() == tagName.lowercased() {
                    if !currentText.isEmpty {
                        children.append(createTextNode(currentText))
                        currentText = ""
                    }
                    scanner.scanString(">")
                    break
                } else {
                    currentText += "</"
                    if let closeTag = closeTag {
                        currentText += closeTag
                    }
                }
            } else {
                if !currentText.isEmpty {
                    children.append(createTextNode(currentText))
                    currentText = ""
                }
                scanner.currentIndex = scanner.string.index(before: scanner.currentIndex)
                if let nested = scanElement(scanner) {
                    children.append(nested)
                }
            }
        }
        
        if !currentText.isEmpty {
            children.append(createTextNode(currentText))
        }
        
        return CSSNode(
            type: .element,
            tagName: tagName.lowercased(),
            attributes: attributes,
            children: children
        )
    }
    
    private func scanTagName(_ scanner: Scanner) -> String? {
        let characters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return scanner.scanCharacters(from: characters)
    }
    
    private func scanAttributes(_ scanner: Scanner) -> [String: String] {
        var attributes: [String: String] = [:]
        
        while !scanner.isAtEnd {
            scanner.scanCharacters(from: .whitespacesAndNewlines)
            
            if scanner.scanString(">") != nil || scanner.scanString("/>") != nil {
                scanner.currentIndex = scanner.string.index(before: scanner.currentIndex)
                break
            }
            
            guard let name = scanAttributeName(scanner) else {
                break
            }
            
            scanner.scanCharacters(from: .whitespacesAndNewlines)
            
            var value = ""
            if scanner.scanString("=") != nil {
                scanner.scanCharacters(from: .whitespacesAndNewlines)
                value = scanAttributeValue(scanner)
            }
            
            attributes[name.lowercased()] = value
        }
        
        return attributes
    }
    
    private func scanAttributeName(_ scanner: Scanner) -> String? {
        let characters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_:"))
        return scanner.scanCharacters(from: characters)
    }
    
    private func scanAttributeValue(_ scanner: Scanner) -> String {
        if let quote = scanner.scanCharacter(), quote == "\"" || quote == "'" {
            let value = scanner.scanUpToString(String(quote)) ?? ""
            scanner.scanCharacter()
            return value
        }
        return scanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ">/"))) ?? ""
    }
    
    private func createTextNode(_ text: String) -> CSSNode {
        return CSSNode(
            type: .text,
            textContent: text
        )
    }
}
