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
    func testPrepareOriginalDictionaryForDedicatedNativeJourney() async throws {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == "Reader-iPhone-Daily-External-20261123" else {
            XCTFail("Dictionary journey setup requires the dedicated simulator")
            return
        }
        let rulesURL = try ReaderLocalFormatsTests.originalURL(format: "json", byteCount: 6_531,
            digest: "664149381e86b68f388a127c9f8531bf1753d0388f5d8c453375a322437a0734")
        let rules = try JSONDecoder().decode([ReaderDictionaryRule].self, from: Data(contentsOf: rulesURL))
        let rule = try XCTUnwrap(rules.first { $0.name == "海词英文" && $0.enabled })
        let service = try await ReaderAppRuntimeStore.shared.library()
        let books = try await service.listBooks()
        let existing = try await service.dictionaryRules()
        let expectedBook = "local:997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        guard books.map(\.bookId) == [expectedBook], existing.isEmpty || existing == [rule] else {
            XCTFail("Expected only the admitted TXT and at most its exact original dictionary rule")
            return
        }
        if existing.isEmpty {
            let operationID = UUID().uuidString
            let saved = try await service.putDictionaryRule(rule, operationID: operationID)
            let confirmed = try await service.isCoreOperationCompleted(operationID)
            XCTAssertEqual(saved, rule)
            XCTAssertTrue(confirmed)
        }
        #else
        throw XCTSkip("Dictionary journey setup is simulator-only")
        #endif
    }

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

    /// Reuse the one already captured real HTTP response. This follow-up never
    /// creates a Core, saves a rule, accesses credentials or performs a query.
    func testRealOriginalDictionaryDefinitionLoadsBundledUIFontInWebKit() async throws {
        let digest = "6d246b03e02e39b208b6aa6c407c945f2d2e0c0b50f22e58296965eaa6254096"
        let host = ReaderDictionaryDefinitionHost()
        var window: UIWindow?
        var phase = "locate unchanged previously captured real response"
        var facts: [String: Any] = ["responseBytes": 2_247, "responseSHA256": digest,
                                   "newDictionaryQueries": 0, "newCoreInstances": 0]
        defer { host.retire(); window?.isHidden = true }
        do {
            let input = try ReaderLocalFormatsTests.originalURL(format: "html", byteCount: 2_247, digest: digest)
            let original = try Data(contentsOf: input)
            try require(original.count == 2_247 && hash(original) == digest,
                        "Use only the unchanged real dictionary response captured previously")
            let definition = try XCTUnwrap(String(data: original, encoding: .utf8))
            try require(["Project", "计划", "工程", "项目"].allSatisfy { definition.contains($0) },
                        "The retained response must contain its actual headword and meanings")
            let captionSize = ReaderTypography.style(.caption).size
            let font = ReaderFonts.uiFont(.ui, size: captionSize)
            let fontAsset = try ReaderEbookFontAsset.prepare(postScriptName: font.fontName)
            let family = ReaderDictionaryDefinitionHost.bundledFontFamily
            facts["nativePostScriptName"] = font.fontName; facts["expectedFontSize"] = captionSize
            facts["expectedBundledFontBytes"] = fontAsset.0.count
            facts["expectedBundledFontSHA256"] = hash(fontAsset.0)

            phase = "load actual response with the production Reader UI face"
            let web = host.webView
            web.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
            let renderedWindow = UIWindow(frame: web.bounds)
            let controller = UIViewController(); controller.view = web
            renderedWindow.rootViewController = controller; renderedWindow.isHidden = false
            window = renderedWindow
            let displayID = UUID()
            let deadline = Task { @MainActor in
                try await Task.sleep(nanoseconds: 12_000_000_000)
                host.retire()
            }
            defer { deadline.cancel() }
            try await host.load(definition: definition, displayID: displayID,
                style: ReaderDictionaryDefinitionStyle(font: font, foreground: .black,
                                                        background: .white, link: .blue))
            deadline.cancel()
            try require(host.loadedDisplayID == displayID, "The actual font-ready result must retain its original display identity")

            phase = "observe actual FontFaceSet, original embedded font bytes and rendered text"
            let measured = try await web.callAsyncJavaScript(Self.measureActualBundledFont,
                arguments: ["family": family], in: nil, contentWorld: .defaultClient)
            var dom = try XCTUnwrap(measured as? [String: Any])
            // Font bytes cross into WebKit. Check that exact original data,
            // but keep the large base64 source out of diagnostic attachments.
            let dataURL = try XCTUnwrap(dom.removeValue(forKey: "fontDataURL") as? String)
            let prefix = "data:" + fontAsset.1 + ";base64,"
            try require(dataURL.hasPrefix(prefix), "The production CSS face must use its original MIME and a data URL")
            let embeddedBytes = try XCTUnwrap(Data(base64Encoded: String(dataURL.dropFirst(prefix.count))))
            facts["embeddedFontBytes"] = embeddedBytes.count; facts["embeddedFontSHA256"] = hash(embeddedBytes)
            facts["render"] = dom
            try attach(facts, name: "real-dictionary-bundled-UI-font-actual-FontFaceSet")
            try require(embeddedBytes == fontAsset.0,
                        "WebKit must receive the exact Reader UI font asset, without rewritten font tables")
            let measuredSize = try XCTUnwrap(dom["fontSize"] as? NSNumber).doubleValue
            try require(dom["cssFamily"] as? String == family && dom["resultFontFamily"] as? String == family
                        && abs(measuredSize - Double(captionSize)) < 0.01
                        && dom["fontSetStatus"] as? String == "loaded"
                        && dom["matchingFontFaces"] as? Int == 1 && dom["loadedFontFaces"] as? Int == 1,
                        "The exact data font must be an actually loaded FontFaceSet member and the first rendered Reader family at the exact caption size")
            try require(dom["realTextVisible"] as? Bool == true && dom["literalMarkupVisible"] as? Bool == false
                        && dom["resultVisible"] as? Bool == true && dom["fontFaceRules"] as? Int == 1,
                        "The real response must remain readable in the actual loaded font document")
            try require(dom["dataOnlyFontCSP"] as? Bool == true && dom["otherResourcesDenied"] as? Bool == true
                        && dom["remoteCSSURLs"] as? Int == 0 && dom["resourceAttributes"] as? Int == 0
                        && dom["sourceScripts"] as? Int == 0 && dom["eventAttributes"] as? Int == 0
                        && !web.configuration.defaultWebpagePreferences.allowsContentJavaScript
                        && !web.configuration.websiteDataStore.isPersistent,
                        "Bundled data fonts must preserve the source-script and HTTP subresource restrictions")
            try require(try Data(contentsOf: input) == original, "The real response original must remain unchanged")
            host.retire(); renderedWindow.isHidden = true
            try require(host.loadedDisplayID == nil, "Retirement must remove the loaded display identity")
            facts["inputBytesPreserved"] = true; facts["retiredDisplayIdentityCleared"] = true
            facts["result"] = "real response rendered with the exact loaded bundled Reader UI font"
            try attach(facts, name: "real-dictionary-bundled-UI-font-and-retirement-complete")
        } catch {
            facts["failedPhase"] = phase; facts["failure"] = String(describing: error)
            try? attach(facts, name: "real-dictionary-bundled-UI-font-failure-stage")
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

    /// Read the already loaded platform font face and safe document. A matching
    /// CSS family string or fonts.check on an unknown family is insufficient.
    private static let measureActualBundledFont = #"""
    const root=document.getElementById('reader-dictionary-definition');
    if(!root)return {missingContainer:true};
    const clean=value=>String(value).replace(/["']/g,'').trim();
    const rules=[...document.getElementById('reader-dictionary-style').sheet.cssRules];
    const fontRules=rules.filter(rule=>rule.type===CSSRule.FONT_FACE_RULE);
    const fontRule=fontRules.find(rule=>clean(rule.style.fontFamily)===family);
    const src=fontRule?.style.getPropertyValue('src')||'';
    const dataURL=src.match(/url\(\s*["']?(data:[^"')\s]+)["']?\s*\)/i)?.[1]||'';
    const faces=[...document.fonts].filter(face=>clean(face.family)===family);
    const style=getComputedStyle(root),text=root.innerText,rect=root.getBoundingClientRect();
    const csp=document.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content||'';
    const elements=[...document.querySelectorAll('*')];
    const resourceAttributes=elements.reduce((count,node)=>count+[...node.attributes].filter(attribute=>['src','srcset','poster','background','xlink:href'].includes(attribute.name)).length,0);
    const eventAttributes=elements.reduce((count,node)=>count+[...node.attributes].filter(attribute=>attribute.name.toLowerCase().startsWith('on')).length,0);
    return {fontDataURL:dataURL,fontFaceRules:fontRules.length,matchingFontFaces:faces.length,
      loadedFontFaces:faces.filter(face=>face.status==='loaded').length,fontSetStatus:document.fonts.status,
      cssFamily:clean(style.fontFamily.split(',')[0]),resultFontFamily:root.dataset.fontFamily,fontSize:parseFloat(style.fontSize),
      realTextVisible:['Project','计划','工程','项目'].every(value=>text.includes(value)),
      literalMarkupVisible:/<\/?(?:br|div|em|a)(?:\s|>)/i.test(text),
      resultVisible:rect.width>0&&rect.height>0&&rect.top>=0&&rect.top<innerHeight,
      dataOnlyFontCSP:csp.split(';').some(item=>item.trim()==='font-src data:'),
      otherResourcesDenied:['default-src','script-src','img-src','connect-src','media-src','frame-src','object-src'].every(name=>csp.includes(name+" 'none'")),
      remoteCSSURLs:(rules.map(rule=>rule.cssText).join('\n').match(/https?:/gi)||[]).length,
      resourceAttributes,eventAttributes,sourceScripts:document.scripts.length};
    """#
}
