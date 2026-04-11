// ReaderCoreJSRenderer/JSRuntimeDOMBridge.swift
// P2 capability: js_dom_querySelector
//
// CLEAN-ROOM: no Legado Android reference. Pure-JS regex tokeniser DOM polyfill.
//
// SCOPE (P2 js_dom_querySelector only):
//   Supported selectors : tag  .class  #id  tag.class  tag#id
//   Supported DOM ops   : querySelector, querySelectorAll, textContent (r/w),
//                         innerHTML (r/w), outerHTML (r), getAttribute
//   NOT supported       : combinators (>  +  ~), pseudo-classes, network APIs,
//                         localStorage, full CSS spec, multi-frame pages
//
// INTEGRATION:
//   JSRenderingGate protocol (ReaderCoreParser module) is implemented here so
//   NonJSParserEngine can inject this bridge without importing ReaderCoreJSRenderer.

import Foundation
import JavaScriptCore
import ReaderCoreParser          // for JSRenderingGate conformance

// MARK: - Bridge

public final class JSRuntimeDOMBridge: JSRenderingGate, @unchecked Sendable {

    public static let shared = JSRuntimeDOMBridge()

    private let timeoutMilliseconds: Int

    public init(timeoutMilliseconds: Int = 1500) {
        self.timeoutMilliseconds = max(100, min(timeoutMilliseconds, 5000))
    }

    // MARK: JSRenderingGate

    /// Execute `evalScript` against the DOM built from `html`.
    /// Returns `document.documentElement.outerHTML` after execution,
    /// or `html` unchanged on timeout / JS exception.
    public func execute(html: String, evalScript: String? = nil) -> String {
        var scripts = [Self.domPolyfillScript]
        if let s = evalScript, !s.isEmpty {
            scripts.append(s)
        }
        return JSRuntime.makeForTesting(
            timeoutMilliseconds: timeoutMilliseconds,
            additionalEvaluationScripts: scripts
        ).execute(html: html)
    }
}

// MARK: - DOM Polyfill

extension JSRuntimeDOMBridge {

    /// A pure-JS minimal DOM polyfill for JavaScriptCore.
    ///
    /// Execution order inside JSRuntime:
    ///   1. networkLockdownScript   – blocks fetch / XHR / WebSocket
    ///   2. bootstrapDocumentScript – sets `document` to a frozen stub
    ///   3. domPolyfillScript (this) – overwrites `document` with a live DOM
    ///   4. caller's evalScript     – may use querySelector / innerHTML / etc.
    ///
    /// After all scripts run, JSRuntime reads `document.documentElement.outerHTML`
    /// to produce the return value.
    static let domPolyfillScript = #"""
    (function () {
      "use strict";

      // ── 0. Source HTML ─────────────────────────────────────────────────────
      // __inputHTML is set by JSRuntime before any scripts run.
      var _src = String(__inputHTML);

      // ── 1. Void-element table ──────────────────────────────────────────────
      var VOID = {
        area:1, base:1, br:1, col:1, embed:1, hr:1, img:1, input:1,
        link:1, meta:1, param:1, source:1, track:1, wbr:1
      };

      // ── 2. Attribute parser ────────────────────────────────────────────────
      // Handles: key="val"  key='val'  key=val  key (boolean)
      var ATTR_RE = /([a-zA-Z_:][a-zA-Z0-9_:.-]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'><=`]*)))?/g;

      function parseAttrs(raw) {
        var attrs = {}, m;
        ATTR_RE.lastIndex = 0;
        while ((m = ATTR_RE.exec(raw)) !== null) {
          if (!m[1]) continue;
          var k = m[1].toLowerCase();
          var v = (m[2] !== undefined) ? m[2]
                : (m[3] !== undefined) ? m[3]
                : (m[4] !== undefined) ? m[4]
                : "";
          attrs[k] = v;
        }
        return attrs;
      }

      // ── 3. Element ────────────────────────────────────────────────────────
      // _texts[i] = text that appears before children[i].
      // _texts[children.length] = trailing text after the last child.
      // Invariant: _texts.length === children.length + 1
      function Elem(tag, attrs) {
        this.tagName    = tag.toUpperCase();
        this.id         = attrs.id    || "";
        this.className  = attrs.class || "";
        this._attrs     = attrs;
        this.children   = [];
        this._texts     = [""];      // starts with one slot (trailing text)
        this.parentNode = null;
      }

      Elem.prototype.getAttribute = function (name) {
        var v = this._attrs[name.toLowerCase()];
        return (v !== undefined) ? String(v) : null;
      };

      // textContent – get: concatenate all text recursively.
      //             – set: replace subtree with a single text node.
      Object.defineProperty(Elem.prototype, "textContent", {
        get: function () {
          var s = "";
          for (var i = 0; i <= this.children.length; i++) {
            if (this._texts[i]) s += this._texts[i];
            if (i < this.children.length) s += this.children[i].textContent;
          }
          return s;
        },
        set: function (v) {
          this.children = [];
          this._texts   = [String(v)];
        }
      });

      // innerHTML – get: serialize children.
      //           – set: re-parse and replace subtree.
      Object.defineProperty(Elem.prototype, "innerHTML", {
        get: function () { return _serInner(this); },
        set: function (v) {
          var frag = _parse(String(v));
          this.children = frag.children;
          this._texts   = frag._texts;
          for (var i = 0; i < this.children.length; i++) {
            this.children[i].parentNode = this;
          }
        }
      });

      // outerHTML – get only (mutation goes through innerHTML).
      Object.defineProperty(Elem.prototype, "outerHTML", {
        get: function () { return _serElem(this); },
        configurable: true      // documentElement patches this below
      });

      Elem.prototype.querySelector = function (sel) {
        return _qsa(sel, [this])[0] || null;
      };
      Elem.prototype.querySelectorAll = function (sel) {
        return _qsa(sel, [this]);
      };

      // ── 4. Serialiser ─────────────────────────────────────────────────────
      function _attrsStr(el) {
        var out = "";
        if (el.id)        out += ' id="'    + el.id        + '"';
        if (el.className) out += ' class="' + el.className + '"';
        var a = el._attrs;
        for (var k in a) {
          if (!Object.prototype.hasOwnProperty.call(a, k)) continue;
          if (k === "id" || k === "class") continue;
          out += " " + k + '="' + a[k] + '"';
        }
        return out;
      }

      function _serInner(el) {
        var out = el._texts[0] || "";
        for (var i = 0; i < el.children.length; i++) {
          out += _serElem(el.children[i]);
          out += el._texts[i + 1] || "";
        }
        return out;
      }

      function _serElem(el) {
        var tag = el.tagName.toLowerCase();
        if (VOID[tag]) return "<" + tag + _attrsStr(el) + ">";
        return "<" + tag + _attrsStr(el) + ">" + _serInner(el) + "</" + tag + ">";
      }

      // ── 5. Parser ─────────────────────────────────────────────────────────
      // TOKEN_RE matches:
      //   group 1 – "/" for close tags, "" for open
      //   group 2 – tag name
      //   group 3 – raw attribute string
      //   group 4 – text node (when group 2 is undefined)
      var TOKEN_RE = /<(\/?)([a-zA-Z][a-zA-Z0-9:-]*)([^>]*)\/?>|([^<]+)/g;

      function _parse(html) {
        var root = new Elem("__ROOT__", {});
        var stack = [root];

        TOKEN_RE.lastIndex = 0;
        var m;
        while ((m = TOKEN_RE.exec(html)) !== null) {
          var isClose  = (m[1] === "/");
          var tagLower = m[2] ? m[2].toLowerCase() : null;
          var rawAttrs = m[3] || "";
          var text     = m[4];

          var top = stack[stack.length - 1];

          if (text !== undefined) {
            // Append text to the slot after the last child of `top`.
            var ti = top.children.length;
            top._texts[ti] = (top._texts[ti] || "") + text;
            continue;
          }

          if (isClose) {
            // Unwind the stack to the matching open tag.
            for (var si = stack.length - 1; si > 0; si--) {
              if (stack[si].tagName.toLowerCase() === tagLower) {
                stack.length = si;
                break;
              }
            }
            continue;
          }

          // Open tag: create element, add to parent, push onto stack.
          var el = new Elem(tagLower, parseAttrs(rawAttrs));
          top.children.push(el);
          top._texts.push("");     // new trailing-text slot
          el.parentNode = top;

          if (!VOID[tagLower]) {
            stack.push(el);
          }
        }

        return root;
      }

      // ── 6. CSS selector matching ──────────────────────────────────────────
      // Supported: tag  .class  #id  tag.class  tag#id  (single simple selector)
      function _parseSel(sel) {
        var s      = sel.trim();
        var tag    = null;
        var id     = null;
        var classes = [];

        var tm = /^([a-zA-Z][a-zA-Z0-9]*)/.exec(s);
        if (tm) { tag = tm[1].toUpperCase(); s = s.slice(tm[0].length); }

        var qr = /([#.])([a-zA-Z_-][a-zA-Z0-9_-]*)/g;
        var qm;
        while ((qm = qr.exec(s)) !== null) {
          if (qm[1] === "#") id = qm[2];
          else               classes.push(qm[2]);
        }
        return { tag: tag, id: id, classes: classes };
      }

      function _matches(el, p) {
        if (p.tag && el.tagName !== p.tag) return false;
        if (p.id  && el.id      !== p.id)  return false;
        if (p.classes.length > 0) {
          var ec = " " + (el.className || "") + " ";
          for (var i = 0; i < p.classes.length; i++) {
            if (ec.indexOf(" " + p.classes[i] + " ") === -1) return false;
          }
        }
        return true;
      }

      function _walk(el, p, acc) {
        if (el.tagName !== "__ROOT__" && _matches(el, p)) acc.push(el);
        for (var i = 0; i < el.children.length; i++) {
          _walk(el.children[i], p, acc);
        }
      }

      function _qsa(selector, roots) {
        var p   = _parseSel(selector);
        var acc = [];
        for (var r = 0; r < roots.length; r++) { _walk(roots[r], p, acc); }
        return acc;
      }

      // ── 7. Build document object ──────────────────────────────────────────
      var _root = _parse(_src);

      // Find the <html> element (or fall back to first child).
      var _docEl = null;
      for (var _i = 0; _i < _root.children.length; _i++) {
        if (_root.children[_i].tagName === "HTML") {
          _docEl = _root.children[_i];
          break;
        }
      }
      if (!_docEl) {
        _docEl = (_root.children.length > 0)
               ? _root.children[0]
               : new Elem("html", {});
      }

      // Patch documentElement.outerHTML so JSRuntime's extraction reads the
      // full serialised document (including text outside <html>, e.g. <!DOCTYPE>).
      Object.defineProperty(_docEl, "outerHTML", {
        get: function () {
          var out = _root._texts[0] || "";
          for (var i = 0; i < _root.children.length; i++) {
            out += _serElem(_root.children[i]);
            out += _root._texts[i + 1] || "";
          }
          return out;
        },
        configurable: true
      });

      // Overwrite the frozen document stub created by bootstrapDocumentScript.
      this.document = {
        documentElement: _docEl,
        querySelector:    function (sel) { return _qsa(sel, [_root])[0] || null; },
        querySelectorAll: function (sel) { return _qsa(sel, [_root]); },
        get body() { return _qsa("body", [_root])[0] || null; },
        get head() { return _qsa("head", [_root])[0] || null; }
      };

    })();
    """#
}
