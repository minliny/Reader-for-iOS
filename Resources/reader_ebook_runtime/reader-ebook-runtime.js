(() => {
  'use strict';

  if (window !== window.top) throw Error('MAIN_FRAME_REQUIRED');

  const allowedTags = new Set(('a abbr address article aside b bdi bdo blockquote br caption cite code col colgroup dd del dfn div dl dt em figcaption figure footer h1 h2 h3 h4 h5 h6 header hgroup hr i img ins kbd li main mark nav ol p pre q rp rt ruby s samp section small span strong sub sup table tbody td tfoot th thead time tr u ul var wbr').split(' '));
  const inertTags = new Set(['script', 'template', 'title', 'noscript', 'iframe', 'object', 'embed']);
  const attributes = ['id', 'class', 'lang', 'dir', 'title', 'style', 'alt', 'width', 'height', 'rowspan', 'colspan'];
  const resourceSource = /^(?:https:\/\/[a-z0-9.-]+(?::[1-9][0-9]*)?|[a-z][a-z0-9+.-]*:)$/;
  const identifier = /^[a-zA-Z0-9-]{1,128}$/;
  let active = null;

  function relativeArchivePath(entryPath, href) {
    const url = href.trim().split(/[?#]/, 1)[0];
    if (!url || url.length > 32768 || /^([a-z][a-z0-9+.-]*:|\/\/)/i.test(url)) return null;
    let path;
    try {
      path = decodeURIComponent(url).replaceAll('\\', '/');
    } catch {
      return null;
    }
    if (/[\u0000-\u001f\u007f]/.test(path) || path.startsWith('//')) return null;
    const segments = path.startsWith('/') ? [] : entryPath.split('/').slice(0, -1);
    for (const part of path.split('/')) {
      if (part === '..') {
        if (segments.length === 0) return null;
        segments.pop();
      } else if (part && part !== '.') {
        segments.push(part);
      }
    }
    const resolved = segments.join('/');
    return resolved.length && resolved.length <= 2048 ? resolved : null;
  }

  function archiveURL(config, adapter, href) {
    const path = relativeArchivePath(config.entryPath, href);
    return path ? adapter.resourceURL(path) : null;
  }

  function installPublication(document, config, adapter) {
    // The HTML template parser keeps publisher markup inert. Re-create only
    // rendering nodes inside the script-disabled frame, with no author events.
    const template = window.document.createElement('template');
    template.innerHTML = config.xhtml;
    const baseURL = adapter.resourceURL(config.entryPath);
    if (!baseURL) throw Error('PUBLICATION_BASE_UNAVAILABLE');
    const base = document.createElement('base');
    base.href = baseURL;
    document.head.append(base);
    const stylesheetLoads = [];
    const work = [];
    function enqueue(children, parent) {
      for (let i = children.length - 1; i >= 0; i--) work.push({ source: children[i], parent });
    }
    enqueue(template.content.childNodes, document.body);
    while (work.length) {
      const { source, parent } = work.pop();
      if (source.nodeType === Node.TEXT_NODE) {
        parent.append(document.createTextNode(source.data));
        continue;
      }
      if (source.nodeType !== Node.ELEMENT_NODE || inertTags.has(source.localName)) continue;
      const tag = source.localName;
      if (tag === 'style') {
        const style = document.createElement('style');
        style.textContent = source.textContent;
        document.head.append(style);
        continue;
      }
      const rel = source.getAttribute('rel')?.toLowerCase().split(/\s+/);
      if (tag === 'link' && rel?.includes('stylesheet') && !rel.includes('alternate')
        && !source.hasAttribute('disabled')) {
        const url = archiveURL(config, adapter, source.getAttribute('href') ?? '');
        if (url) {
          const stylesheet = document.createElement('link');
          stylesheet.rel = 'stylesheet';
          stylesheet.media = source.getAttribute('media') ?? '';
          if (stylesheet.media.toLowerCase() === 'print') continue;
          stylesheetLoads.push(new Promise(resolve => {
            stylesheet.addEventListener('load', () => resolve(true), { once: true });
            stylesheet.addEventListener('error', () => resolve(false), { once: true });
          }));
          stylesheet.href = url;
          document.head.append(stylesheet);
        }
        continue;
      }
      const image = tag === 'img' || tag === 'image';
      const alias = source.getAttribute('id') ?? source.getAttribute('xml:id') ?? source.getAttribute('name');
      const safeTag = tag === 'form' || tag === 'fieldset' ? 'div' : tag;
      if (!image && !alias && !allowedTags.has(safeTag)) {
        enqueue(source.childNodes, parent);
        continue;
      }
      const element = document.createElement(image ? 'img' : allowedTags.has(safeTag) ? safeTag : 'span');
      for (const attr of attributes) {
        if (source.hasAttribute(attr)) element.setAttribute(attr, source.getAttribute(attr));
      }
      if (alias) element.id = alias;
      if (image) {
        const href = source.getAttribute('src') ?? source.getAttribute('data-src')
          ?? source.getAttribute('xlink:href') ?? source.getAttribute('href') ?? '';
        const url = archiveURL(config, adapter, href);
        if (!url) continue;
        element.setAttribute('data-reader-archive-image', '');
        element.loading = 'eager';
        element.src = url;
      } else if (tag === 'a' && source.hasAttribute('href')) {
        const href = source.getAttribute('href');
        element.setAttribute('data-reader-href', href);
        element.href = '#';
      }
      parent.append(element);
      enqueue(source.childNodes, element);
    }
    return stylesheetLoads;
  }

  function publish(state, expected, kind, value) {
    if (!same(state, expected)) return;
    state.adapter.postMessage({
      version: 1, session: state.session, documentId: state.documentId,
      layoutGeneration: expected, kind, value,
    });
  }

  function close() {
    const previous = active;
    active = null;
    previous?.eventListeners?.abort();
    previous?.frame?.remove();
  }

  function fail(state, expected, error) {
    if (!same(state, expected)) return;
    publish(state, expected, 'failure', { code: String(error?.message ?? 'EBOOK_UNAVAILABLE').slice(0, 128) });
    if (same(state, expected)) close();
  }

  function requireIdentity(value) {
    if (typeof value !== 'string' || !identifier.test(value)) throw Error('INVALID_RENDER_IDENTITY');
    return value;
  }

  function generation(value) {
    if (!Number.isSafeInteger(value) || value < 0) throw Error('INVALID_LAYOUT_GENERATION');
    return value;
  }

  function wait(deadline, operation) {
    let timer;
    return Promise.race([
      operation,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(Error('PUBLICATION_LAYOUT_TIMEOUT')), deadline);
      }),
    ]).finally(() => clearTimeout(timer));
  }

  function loadedFrame(state) {
    const frame = document.createElement('iframe');
    frame.title = '书籍正文';
    frame.setAttribute('sandbox', 'allow-same-origin');
    frame.referrerPolicy = 'no-referrer';
    frame.style.visibility = 'hidden';
    const origin = state.adapter.resourceCSPSource;
    const policy = `default-src 'none'; style-src 'unsafe-inline' ${origin}; img-src ${origin}; font-src ${origin}; base-uri ${origin}; form-action 'none'`;
    const loaded = new Promise(resolve => {
      const onLoad = () => {
        const publication = frame.contentDocument;
        const policyTag = publication?.querySelector('meta[http-equiv="Content-Security-Policy"]');
        if (frame.contentWindow?.location.href !== 'about:srcdoc' || policyTag?.content !== policy) return;
        frame.removeEventListener('load', onLoad);
        resolve(publication);
      };
      frame.addEventListener('load', onLoad);
    });
    frame.srcdoc = `<!doctype html><html lang="zh"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${policy}"></head><body></body></html>`;
    state.frame = frame;
    document.body.append(frame);
    return wait(3000, loaded);
  }

  function safeNumber(value, fallback, minimum, maximum) {
    if (value === undefined) return fallback;
    if (!Number.isFinite(value) || value < minimum || value > maximum) throw Error('INVALID_EBOOK_STYLE');
    return value;
  }

  function applyStyle(state, style = {}) {
    const document = state.frame.contentDocument;
    const view = document.defaultView;
    const root = document.documentElement;
    const body = document.body;
    const size = safeNumber(style.fontSize, 18, 10, 72);
    const lineHeight = safeNumber(style.lineHeight, size * 1.96, size, 160);
    const top = safeNumber(style.topInset, 18, 0, 200);
    const horizontal = safeNumber(style.horizontalInset, 19, 0, 120);
    const paragraph = safeNumber(style.paragraphSpacing, 16, 0, 80);
    function color(value, fallback) {
      if (value === undefined) return fallback;
      if (typeof value !== 'string' || !/^#[0-9a-f]{6}$/i.test(value)) throw Error('INVALID_EBOOK_STYLE');
      return value;
    }
    root.style.setProperty('background', color(style.paper, '#FAF7F0'), 'important');
    root.style.setProperty('color-scheme', style.dark === true ? 'dark' : 'light');
    body.style.setProperty('background', 'transparent', 'important');
    body.style.setProperty('color', color(style.ink, '#1D1B18'), 'important');
    body.style.setProperty('font-size', `${size}px`, 'important');
    body.style.setProperty('line-height', `${lineHeight}px`, 'important');
    body.style.setProperty('margin', '0', 'important');
    body.style.setProperty('padding', `${top}px ${horizontal}px ${view.innerHeight}px`, 'important');
    body.style.setProperty('box-sizing', 'border-box', 'important');
    body.style.setProperty('overflow-wrap', 'anywhere', 'important');
    body.style.setProperty('--reader-paragraph-spacing', `${paragraph}px`);
    state.dom.setTopInset(top);
  }

  function waitForAssets(document, stylesheets) {
    const loaded = Array.from(document.images, image => {
      if (image.complete) return Promise.resolve();
      return new Promise(resolve => {
        image.addEventListener('load', resolve, { once: true });
        image.addEventListener('error', resolve, { once: true });
      });
    });
    const fonts = Promise.all(stylesheets).then(results => {
      if (results.includes(false)) throw Error('PUBLICATION_STYLESHEET_UNAVAILABLE');
      return document.fonts.ready;
    });
    return wait(5000, Promise.all([...loaded, fonts])).then(() => {
      if (Array.from(document.images).some(image => image.naturalWidth <= 0)) {
        throw Error('PUBLICATION_IMAGE_UNAVAILABLE');
      }
    });
  }

  const paint = view => wait(3000, new Promise(resolve => view.requestAnimationFrame(() => view.requestAnimationFrame(resolve))));
  const same = (state, expected) => active === state && state.generation === expected;

  async function layout(state, expected, style, anchor) {
    state.eventListeners?.abort();
    state.ready = false;
    state.interacted = false;
    state.restored = null;
    state.requestedAnchor = anchor;
    const document = state.frame.contentDocument;
    const view = document.defaultView;
    view.getSelection()?.removeAllRanges();
    applyStyle(state, style);
    await waitForAssets(document, state.stylesheetLoads);
    if (!same(state, expected)) return;
    state.frame.style.visibility = 'visible';
    state.dom.restore(anchor);
    await paint(view);
    if (!same(state, expected)) return;
    const position = state.dom.restore(anchor);
    if (!position) throw Error('ANCHOR_GEOMETRY_UNAVAILABLE');
    state.restored = position;
    state.ready = true;
    attachEvents(state, expected, document);
    publish(state, expected, 'ready', {
      ...position,
      loadedImageCount: document.images.length,
    });
  }

  function attachEvents(state, expected, document) {
    const view = document.defaultView;
    const listeners = new AbortController();
    state.eventListeners = listeners;
    const { signal } = listeners;
    const interact = event => {
      if (same(state, expected) && state.ready && event.isTrusted) state.interacted = true;
    };
    for (const type of ['pointerdown', 'touchstart', 'wheel', 'keydown']) {
      document.addEventListener(type, interact, { passive: true, capture: true, signal });
    }
    let queued = false;
    view.addEventListener('scroll', () => {
      if (!state.ready || !state.interacted || queued) return;
      queued = true;
      view.requestAnimationFrame(() => {
        queued = false;
        if (!same(state, expected) || !state.ready || state.dom.selection()) return;
        const position = state.dom.position();
        if (position) {
          state.restored = null;
          publish(state, expected, 'position', position);
        }
      });
    }, { passive: true, signal });
    document.addEventListener('selectionchange', () => {
      if (state.ready) publish(state, expected, 'selection', state.dom.selection());
    }, { signal });
    document.addEventListener('click', event => {
      const link = event.target?.closest?.('[data-reader-href]');
      if (link) event.preventDefault();
      if (!same(state, expected) || !state.ready || !event.isTrusted || state.dom.selection()) return;
      if (!link) {
        publish(state, expected, 'tap', null);
        return;
      }
      const href = link.getAttribute('data-reader-href');
      const fragmentStart = href.indexOf('#');
      let fragment;
      try {
        fragment = fragmentStart < 0 ? null : decodeURIComponent(href.slice(fragmentStart + 1));
      } catch {
        return;
      }
      const path = href.startsWith('#') ? state.entryPath : relativeArchivePath(state.entryPath, href);
      if (!path) return;
      const target = path === state.entryPath && fragment ? document.getElementById(fragment) : null;
      const scalar = target ? state.dom.scalarAtElement(target) : null;
      const position = scalar === null ? null : state.dom.restore(scalar);
      if (position) {
        state.restored = position;
        publish(state, expected, 'position', position);
      } else {
        publish(state, expected, 'link', { entryPath: path, fragment });
      }
    }, { capture: true, signal });
  }

  async function open(configuration, adapter) {
    const session = requireIdentity(configuration.session);
    const documentId = requireIdentity(configuration.documentId);
    const observed = generation(configuration.layoutGeneration);
    if (typeof adapter?.resourceCSPSource !== 'string' || !resourceSource.test(adapter.resourceCSPSource)
      || ['data:', 'blob:', 'file:', 'javascript:', 'http:', 'https:'].includes(adapter.resourceCSPSource)
      || typeof adapter.resourceURL !== 'function' || typeof adapter.postMessage !== 'function') {
      throw Error('NATIVE_EBOOK_ADAPTER_REQUIRED');
    }
    close();
    const state = { session, documentId, generation: observed, entryPath: configuration.entryPath, adapter };
    active = state;
    try {
      const document = await loadedFrame(state);
      if (!same(state, observed)) return;
      state.stylesheetLoads = installPublication(document, configuration, adapter);
      state.dom = window.ReaderEbookDom.create(document, configuration);
      const stylesheet = document.createElement('style');
      stylesheet.textContent = `
        html { overscroll-behavior: contain; overflow-x: hidden !important; scroll-behavior: auto !important; }
        body { -webkit-text-size-adjust: 100%; overflow: visible !important; font-family: serif; }
        p { margin: 0 0 var(--reader-paragraph-spacing) !important; text-align: justify; }
        img { max-width: 100% !important; height: auto !important; }
      `;
      document.head.append(stylesheet);
      await layout(state, observed, configuration.style, configuration.anchor);
    } catch (error) {
      fail(state, observed, error);
    }
  }

  function matches(session, documentId) {
    return active && active.session === session && active.documentId === documentId;
  }

  function snapshot(state = active) {
    if (!state?.ready) return null;
    return state.restored ?? state.dom.position();
  }

  async function reflow(session, documentId, expected, style, anchor) {
    if (!matches(session, documentId) || !active.dom || generation(expected) <= active.generation) return;
    const state = active;
    const retained = anchor ?? snapshot(state)?.scalar ?? state.requestedAnchor;
    state.generation = expected;
    try {
      if (retained === undefined) throw Error('ANCHOR_GEOMETRY_UNAVAILABLE');
      await layout(state, expected, style, retained);
    } catch (error) {
      fail(state, expected, error);
    }
  }

  Object.defineProperty(window, 'ReaderEbookRuntime', {
    value: Object.freeze({
      open,
      reflow,
      position: () => snapshot(),
      selection: () => active?.ready ? active.dom.selection() : null,
      select(start, end) { return active?.ready ? active.dom.select(start, end) : null; },
      restore(scalar) {
        const state = active;
        if (!state?.ready) return null;
        const expected = state.generation;
        const position = state.dom.restore(scalar);
        if (position) {
          state.restored = position;
          publish(state, expected, 'position', position);
        }
        return position;
      },
      retire(session, documentId) { if (matches(session, documentId)) close(); },
    }),
  });
})();
