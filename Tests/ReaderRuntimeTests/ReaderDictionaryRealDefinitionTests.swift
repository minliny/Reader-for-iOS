import CryptoKit
import Foundation
import Security
import UIKit
import WebKit
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

@MainActor
final class ReaderDictionaryRealDefinitionTests: XCTestCase {
    /// The delivery owner provisions the unchanged upstream rule array and
    /// Gutenberg original into Documents. Neither rules nor HTTP responses are
    /// embedded here. This method uses the normal Core + native HTTP path once.
    func testRealOriginalDictionaryRuleQueriesAndRendersDefinitionWithoutChangingInputs() async throws {
        let rulesDigest = "664149381e86b68f388a127c9f8531bf1753d0388f5d8c453375a322437a0734"
        let bookDigest = "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealDictionary-" + UUID().uuidString,
                                                                    isDirectory: true)
        let operations = root.appendingPathComponent("Sources/.operations", isDirectory: true)
        let identityURL = operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
        var library: ReaderLibraryService?
        var admittedCookieQuery: [String: Any]?
        var identityBytes: Data?
        var phase = "locate unchanged real input files"
        var facts: [String: Any] = ["temporaryRoot": root.path, "ruleInputSHA256": rulesDigest,
                                   "bookInputSHA256": bookDigest, "networkCallsRequested": 0]
        let host = ReaderDictionaryDefinitionHost()
        var window: UIWindow?
        defer { host.retire(); window?.isHidden = true }

        do {
            let rulesURL = try ReaderLocalFormatsTests.originalURL(format: "json", byteCount: 6_531, digest: rulesDigest)
            let bookURL = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 99_898, digest: bookDigest)
            let ruleBytes = try Data(contentsOf: rulesURL)
            let bookBytes = try Data(contentsOf: bookURL)
            try require(ruleBytes.count == 6_531 && hash(ruleBytes) == rulesDigest
                        && bookBytes.count == 99_898 && hash(bookBytes) == bookDigest,
                        "Both provisioned real originals must retain their exact bytes and SHA256")
            let rules = try JSONDecoder().decode([ReaderDictionaryRule].self, from: ruleBytes)
            let selectedRules = rules.filter { $0.name == "海词英文" }
            try require(rules.count == 5 && selectedRules.count == 1, "Select the complete original dictionary entry once")
            let originalRule = try XCTUnwrap(selectedRules.first)
            try require(originalRule.enabled, "The selected original rule must be enabled")
            // This is the original file header's word, not a Core body offset
            // or generated English book. Do not normalize or replace it.
            let originalScalars = Array(try XCTUnwrap(String(data: bookBytes, encoding: .utf8)).unicodeScalars)
            try require(originalScalars.count >= 11, "The genuine original must contain its recorded word range")
            let word = String(String.UnicodeScalarView(originalScalars[4..<11]))
            try require(word == "Project", "The lookup term must be the genuine original's scalar 4..<11")
            facts["ruleArrayCount"] = rules.count; facts["ruleName"] = originalRule.name
            facts["originalFileScalarOffset"] = 4; facts["originalWord"] = word
            facts["urlRuleUTF8SHA256"] = hash(Data(originalRule.urlRule.utf8))
            facts["showRuleUTF8SHA256"] = hash(Data(originalRule.showRule.utf8))

            phase = "admit only this temporary library's original credential pair"
            try require(!manager.fileExists(atPath: root.path), "The UUID root must not pre-exist")
            let identity = try ReaderHostLibraryIdentity.loadOrCreate(in: operations)
            identityBytes = try Data(contentsOf: identityURL)
            let components = try XCTUnwrap(URLComponents(string: originalRule.urlRule))
            let requestHost = try XCTUnwrap(components.host)
            try require(components.scheme?.lowercased() == "https" && !requestHost.isEmpty,
                        "The unchanged complete rule must have its original HTTPS host")
            // dict-rule.query carries no sourceId. Production transport.key
            // therefore uses the original request URL host, within this fresh
            // library UUID namespace. It does not share the user's cookie pair.
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "io.reader.minliny.source-cookies." + hash(Data(identity.utf8)),
                kSecAttrAccount as String: hash(Data(requestHost.utf8))]
            var initialQuery = query; initialQuery[kSecReturnData as String] = true
            var existing: CFTypeRef?
            let initialStatus = SecItemCopyMatching(initialQuery as CFDictionary, &existing)
            try require(initialStatus == errSecItemNotFound,
                        "Only a previously absent, exact UUID library credential pair is admitted")
            admittedCookieQuery = query
            facts["credentialPairInitiallyAbsent"] = true
            let active = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core", isDirectory: true),
                                                  sourceURL: root.appendingPathComponent("Sources", isDirectory: true))
            library = active
            let originalBookIdentity = ReaderBook(bookId: "local:" + bookDigest, title: "阿Ｑ正傳")
            let beforeShelf = try await active.listBooks()
            let beforeProgress = try await active.progress(for: originalBookIdentity)
            let beforeRules = try await active.dictionaryRules()
            let beforePending = try await active.pendingCoreCommands()
            try require(beforeShelf.isEmpty && !beforeProgress.found && beforeProgress.progress == nil
                        && beforeRules.isEmpty && beforePending.isEmpty,
                        "The independent library must begin without books, original-book progress, rules or pending writes")

            phase = "save the complete original rule and confirm its original ACK"
            let operationID = UUID().uuidString
            let saved = try await active.putDictionaryRule(originalRule, operationID: operationID)
            let originalOperationCompleted = try await active.isCoreOperationCompleted(operationID)
            try require(saved == originalRule && originalOperationCompleted,
                        "The real original put ACK must preserve every rule field")
            facts["originalPutOperationID"] = operationID; facts["originalPutACKConfirmed"] = true

            phase = "one production Core dictionary query and actual native HTTP fetch"
            facts["networkCallsRequested"] = 1
            let started = Date()
            let definition = try await active.queryDictionary(ruleName: saved.name, word: word)
            facts["querySeconds"] = Date().timeIntervalSince(started)
            let definitionBytes = Data(definition.utf8)
            facts["definitionUTF8Bytes"] = definitionBytes.count
            facts["definitionUTF8SHA256"] = hash(definitionBytes)
            try attach(facts, name: "real-dictionary-original-query-terminal")
            try require([word, "计划", "工程", "项目"].allSatisfy { definition.contains($0) }
                        && definition.lowercased().contains("<br") && definition.lowercased().contains("<div"),
                        "The actual Core definition must contain this headword, real meanings and source HTML structure")

            phase = "render the actual returned HTML in the production dictionary host"
            let web = host.webView
            web.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
            let renderedWindow = UIWindow(frame: web.bounds)
            let controller = UIViewController(); controller.view = web
            renderedWindow.rootViewController = controller; renderedWindow.isHidden = false
            window = renderedWindow
            let displayID = UUID()
            let renderDeadline = Task { @MainActor in
                try await Task.sleep(nanoseconds: 12_000_000_000)
                host.retire()
            }
            defer { renderDeadline.cancel() }
            try await host.load(definition: definition, displayID: displayID,
                style: ReaderDictionaryDefinitionStyle(font: .systemFont(ofSize: 18), foreground: .black,
                                                        background: .white, link: .blue))
            renderDeadline.cancel()
            try require(host.loadedDisplayID == displayID, "The completed document must belong to this exact result display")
            let measured = try await web.callAsyncJavaScript(Self.measureActualDefinition,
                arguments: ["word": word], in: nil, contentWorld: .defaultClient)
            let dom = try XCTUnwrap(measured as? [String: Any])
            facts["render"] = dom
            facts["sourceJavaScriptEnabled"] = web.configuration.defaultWebpagePreferences.allowsContentJavaScript
            facts["persistentWebDataStore"] = web.configuration.websiteDataStore.isPersistent
            try attach(facts, name: "real-dictionary-actual-WebKit-definition")
            try require(dom["kind"] as? String == "html" && dom["visibleMeanings"] as? Bool == true
                        && dom["literalMarkupVisible"] as? Bool == false && dom["definitionVisible"] as? Bool == true
                        && (dom["brCount"] as? Int ?? 0) > 0 && (dom["divCount"] as? Int ?? 0) > 0
                        && (dom["lineCount"] as? Int ?? 0) > 2 && dom["emphasisPreserved"] as? Bool == true
                        && dom["absoluteDetailLinkPreserved"] as? Bool == true,
                        "Real WebKit must show readable meanings, line breaks, emphasis and the original absolute detail link")
            try require(dom["sourceScripts"] as? Int == 0 && dom["unsafeNodes"] as? Int == 0
                        && dom["remoteResourceAttributes"] as? Int == 0 && dom["eventAttributes"] as? Int == 0
                        && dom["restrictiveCSP"] as? Bool == true
                        && !web.configuration.defaultWebpagePreferences.allowsContentJavaScript
                        && !web.configuration.preferences.javaScriptCanOpenWindowsAutomatically
                        && !web.configuration.websiteDataStore.isPersistent,
                        "The actual definition document must retain the production script and resource restrictions")

            phase = "verify rule, original files, empty shelf/progress and pending journal"
            let afterRules = try await active.dictionaryRules()
            let afterShelf = try await active.listBooks()
            let afterProgress = try await active.progress(for: originalBookIdentity)
            let afterPending = try await active.pendingCoreCommands()
            try require(afterRules == [originalRule] && afterShelf == beforeShelf
                        && afterProgress == beforeProgress && afterPending.isEmpty,
                        "A dictionary read must preserve the original rule and independent shelf/progress/pending state")
            try require(try Data(contentsOf: rulesURL) == ruleBytes && Data(contentsOf: bookURL) == bookBytes,
                        "Both real input files must remain byte-for-byte unchanged")
            try require(try Data(contentsOf: identityURL) == identityBytes,
                        "The temporary library identity must remain its original UUID")
            host.retire(); renderedWindow.isHidden = true
            try await active.close(); library = nil
            facts["runtimeClosed"] = true; facts["inputBytesPreserved"] = true
            facts["emptyShelfPreserved"] = true; facts["absentOriginalBookProgressPreserved"] = true
            facts["pendingCoreCommands"] = afterPending.count; facts["originalRuleFieldsPreserved"] = true

            phase = "remove only the admitted exact credential pair and successful UUID root"
            let admitted = try XCTUnwrap(admittedCookieQuery)
            let removed = SecItemDelete(admitted as CFDictionary)
            var postQuery = admitted; postQuery[kSecReturnData as String] = true
            var remainder: CFTypeRef?
            let remaining = SecItemCopyMatching(postQuery as CFDictionary, &remainder)
            try require((removed == errSecSuccess || removed == errSecItemNotFound) && remaining == errSecItemNotFound,
                        "Cleanup may remove only this previously absent exact credential pair")
            try manager.removeItem(at: root)
            try require(!manager.fileExists(atPath: root.path), "Only the successful test's UUID root must be removed")
            facts["exactCredentialPairAbsent"] = true; facts["temporaryRootRemoved"] = true
            facts["result"] = "real original rule, actual Core/HTTP query and production WebKit definition verified"
            try attach(facts, name: "real-dictionary-query-render-and-input-preservation-complete")
        } catch {
            host.retire(); window?.isHidden = true
            if let library {
                do { try await library.close(); facts["failureRuntimeClosed"] = true }
                catch { facts["failureCloseError"] = String(describing: error) }
            }
            facts["failedPhase"] = phase; facts["failure"] = String(describing: error)
            facts["temporaryRootRetained"] = manager.fileExists(atPath: root.path)
            facts["failureCredentialsRetained"] = admittedCookieQuery != nil
            try? attach(facts, name: "real-dictionary-failure-original-stage-and-retained-UUID-root")
            throw error
        }
    }

    private func require(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else {
            XCTFail(message, file: file, line: line)
            throw ReaderLibraryError.invalidResponse(message)
        }
    }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func attach(_ facts: [String: Any], name: String) throws {
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Observe the platform DOM only; never inject a replacement definition,
    /// synthesize an entry, click a link or fetch a renderer resource.
    private static let measureActualDefinition = """
    const root=document.getElementById('reader-dictionary-definition');
    if(!root)return {missingContainer:true};
    const text=root.innerText;
    const meaning=[...root.querySelectorAll('div')].find(node=>['计划','工程','项目'].every(value=>node.textContent.includes(value)));
    const rect=meaning?.getBoundingClientRect();
    const em=[...root.querySelectorAll('em')].find(node=>node.textContent.toLowerCase()===word.toLowerCase());
    const detail=[...root.querySelectorAll('a[href]')].find(node=>node.textContent.includes('查看详细解释'));
    let detailValid=false;
    if(detail){try{const href=detail.getAttribute('href'),url=new URL(href);detailValid=/^https?:\\/\\//i.test(href)&&['http:','https:'].includes(url.protocol)&&!!url.hostname&&url.pathname.endsWith('/'+word)&&detail.href===href;}catch{}}
    const elements=[...root.querySelectorAll('*')];
    const resources=elements.reduce((count,node)=>count+[...node.attributes].filter(attribute=>['src','srcset','poster','background','xlink:href'].includes(attribute.name)).length,0);
    const events=elements.reduce((count,node)=>count+[...node.attributes].filter(attribute=>attribute.name.toLowerCase().startsWith('on')).length,0);
    const csp=document.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content||'';
    return {kind:root.dataset.kind,visibleMeanings:[word,'计划','工程','项目'].every(value=>text.includes(value)),
      literalMarkupVisible:/<\\/?(?:br|div|em|a)(?:\\s|>)/i.test(text),
      definitionVisible:!!rect&&rect.width>0&&rect.height>0&&rect.top>=0&&rect.top<innerHeight,
      brCount:root.querySelectorAll('br').length,divCount:root.querySelectorAll('div').length,
      lineCount:text.split(/\\r?\\n/).filter(line=>line.trim()).length,
      emphasisPreserved:!!em&&getComputedStyle(em).fontStyle==='italic',absoluteDetailLinkPreserved:detailValid,
      sourceScripts:document.scripts.length,unsafeNodes:root.querySelectorAll('script,style,link,meta,base,iframe,object,embed,form').length,
      remoteResourceAttributes:resources,eventAttributes:events,
      restrictiveCSP:['default-src','script-src','img-src','font-src','connect-src','media-src','frame-src','object-src'].every(name=>csp.includes(name+" 'none'"))};
    """
}
