(() => {
  'use strict';

  const imageScalar = '\uFFFC';
  const whitespace = /^\p{White_Space}$/u;
  const blockTags = new Set(('address article aside blockquote caption dd div dl dt fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 header hgroup li main nav ol p pre section table tbody td tfoot th thead tr ul').split(' '));
  const blockBoundary = Symbol();

  function scalarCount(text) {
    if (typeof text !== 'string') throw Error('CORE_TEXT_REQUIRED');
    let length = 0;
    for (const character of text) {
      const code = character.codePointAt(0);
      if (code >= 0xd800 && code <= 0xdfff) throw Error('UNPAIRED_SURROGATE');
      length++;
    }
    return length;
  }

  function coordinate(value, maximum) {
    if (!Number.isSafeInteger(value) || value < 0 || value > maximum) {
      throw Error('INVALID_SCALAR_COORDINATE');
    }
    return value;
  }

  function chapterWindow(configuration) {
    const { documentCanonicalContent, chapterStartScalar, chapterEndScalar, content } = configuration;
    const length = scalarCount(documentCanonicalContent);
    const start = coordinate(chapterStartScalar, length);
    const end = coordinate(chapterEndScalar, length);
    if (start >= end || scalarCount(content) !== configuration.scalarCount || !configuration.scalarCount) {
      throw Error('CORE_WINDOW_MISMATCH');
    }
    let scalar = 0;
    let from = 0;
    let through = 0;
    for (const character of documentCanonicalContent) {
      if (scalar === end) break;
      if (scalar < start) from += character.length;
      through += character.length;
      scalar++;
    }
    const rawChapter = documentCanonicalContent.slice(from, through);
    // The locator can include one side of a structural separator. Reader
    // trims those edge newlines in the processed chapter. The DOM crop still
    // uses the whole window, and every chapter scalar is verified separately.
    if (rawChapter !== content) {
      const keptAt = rawChapter.indexOf(content);
      if (keptAt < 0 || /[^\n]/.test(rawChapter.slice(0, keptAt))
        || /[^\n]/.test(rawChapter.slice(keptAt + content.length))) {
        throw Error('CORE_PROCESSED_MAPPING_UNPROVEN');
      }
    }
    return { start, end };
  }

  function* significantCharacters(text) {
    let scalar = 0;
    let gap = '';
    for (const character of text) {
      if (whitespace.test(character)) {
        gap += character;
      } else {
        yield { character, scalar, gap };
        gap = '';
      }
      scalar++;
    }
  }

  function* documentPoints(document) {
    const { Node } = document.defaultView;
    const pending = Array.from(document.body.childNodes).reverse();
    let gap = '';
    let previousImage = false;
    while (pending.length) {
      const node = pending.pop();
      if (node === blockBoundary) {
        gap = '\n\n';
        continue;
      }
      if (node.nodeType === Node.ELEMENT_NODE) {
        if (node.hasAttribute('data-reader-archive-image')) {
          yield { node, image: true, character: imageScalar, gap: '\n\n' };
          previousImage = true;
          gap = '';
          continue;
        }
        if (node.localName === 'br' && gap !== '\n\n') gap = '\n';
        if (blockTags.has(node.localName)) {
          gap = '\n\n';
          pending.push(blockBoundary);
        }
        for (let child = node.lastChild; child; child = child.previousSibling) pending.push(child);
        continue;
      }
      if (node.nodeType !== Node.TEXT_NODE) continue;
      let unit = 0;
      for (const character of node.data) {
        const end = unit + character.length;
        if (character === imageScalar) throw Error('DOCUMENT_CANONICAL_MISMATCH');
        if (whitespace.test(character)) {
          gap ||= ' ';
        } else {
          yield { node, start: unit, end, character, gap: previousImage ? '\n\n' : gap };
          previousImage = false;
          gap = '';
        }
        unit = end;
      }
    }
  }

  function* alignedPoints(document, canonical) {
    const reference = significantCharacters(canonical);
    let hasPrevious = false;
    for (const point of documentPoints(document)) {
      const next = reference.next();
      // Inline spaces are semantic. A structural block/line or image boundary
      // must also account for Core's intervening paragraph separators. The
      // cropped edges can omit whitespace with no physical DOM point.
      if (next.done || next.value.character !== point.character || (hasPrevious && next.value.gap !== point.gap)) {
        throw Error('DOCUMENT_CANONICAL_MISMATCH');
      }
      yield { ...point, scalar: next.value.scalar };
      hasPrevious = true;
    }
    if (!reference.next().done) throw Error('DOCUMENT_CANONICAL_MISMATCH');
  }

  function endpoint(point, after = false) {
    if (point.image) {
      const node = point.node.parentNode;
      const index = Array.prototype.indexOf.call(node.childNodes, point.node);
      return { node, offset: index + Number(after) };
    }
    return { node: point.node, offset: after ? point.end : point.start };
  }

  function setBoundary(range, method, { node, offset }) {
    range[method](node, offset);
  }

  function cropChapter(document, canonical, { start, end }) {
    let first = null;
    let last = null;
    for (const point of alignedPoints(document, canonical)) {
      if (point.scalar >= start && point.scalar < end) {
        first ??= endpoint(point);
        last = endpoint(point, true);
      }
    }
    if (!first || !last) throw Error('EMPTY_CHAPTER_WINDOW');
    const range = document.createRange();
    setBoundary(range, 'setStart', first);
    setBoundary(range, 'setEnd', last);
    const ancestors = [];
    let ancestor = range.commonAncestorContainer;
    if (ancestor.nodeType !== document.defaultView.Node.ELEMENT_NODE) ancestor = ancestor.parentElement;
    while (ancestor && ancestor !== document.body) {
      ancestors.push(ancestor);
      ancestor = ancestor.parentElement;
    }
    let chapter = range.cloneContents();
    for (const element of ancestors) {
      const container = element.cloneNode(false);
      container.append(chapter);
      chapter = container;
    }
    document.body.replaceChildren(chapter);
    document.body.normalize();
  }

  function create(document, configuration) {
    const { content, scalarCount: length, documentCanonicalContent } = configuration;
    cropChapter(document, documentCanonicalContent, chapterWindow(configuration));
    const points = Array.from(alignedPoints(document, content));
    const view = document.defaultView;
    let top = 0;

    function firstIndex(lessThanTarget) {
      let left = 0;
      let right = points.length;
      while (left < right) {
        const mid = Math.floor((left + right) / 2);
        if (lessThanTarget(points[mid])) left = mid + 1;
        else right = mid;
      }
      return left;
    }

    function rangeAt(point, includeCharacter = false) {
      const range = document.createRange();
      setBoundary(range, 'setStart', endpoint(point));
      if (includeCharacter) setBoundary(range, 'setEnd', endpoint(point, true));
      else range.collapse(true);
      return range;
    }

    function comparePointBoundary(point, after, target) {
      const pointRange = document.createRange();
      setBoundary(pointRange, 'setStart', endpoint(point, after));
      pointRange.collapse(true);
      return pointRange.compareBoundaryPoints(view.Range.START_TO_START, target);
    }

    function boundaryScalar(node, offset, preferEnd = false) {
      if (!document.body.contains(node)) return null;
      const target = document.createRange();
      target.setStart(node, offset);
      target.collapse(true);
      const index = firstIndex(point => comparePointBoundary(point, false, target) < 0);
      const next = points[index];
      const previous = points[index - 1];
      const beforeScalar = next && comparePointBoundary(next, false, target) === 0 ? next.scalar : null;
      const afterScalar = previous && comparePointBoundary(previous, true, target) === 0 ? previous.scalar + 1 : null;
      return preferEnd ? afterScalar ?? beforeScalar : beforeScalar ?? afterScalar;
    }

    function measure(point) {
      const box = point.image ? point.node.getBoundingClientRect() : rangeAt(point, true).getBoundingClientRect();
      return {
        scalar: point.scalar,
        text: point.character,
        rect: { x: box.x, y: box.y, width: box.width, height: box.height },
      };
    }

    function hasGeometry({ x, y, width, height }) {
      return [x, y, width, height].every(Number.isFinite) && width > 0 && height > 0;
    }

    function visible({ rect }) {
      const { x, y, width, height } = rect;
      return hasGeometry(rect) && x + width > 0 && x < view.innerWidth && y + height > 0 && y < view.innerHeight;
    }

    function restorePoint(point) {
      const before = measure(point);
      const element = point.image ? point.node : point.node.parentElement;
      if (!hasGeometry(before.rect) || view.getComputedStyle(element).visibility !== 'visible') return null;
      view.scrollTo(0, Math.max(0, view.scrollY + before.rect.y - top));
      const after = measure(point);
      return visible(after) ? after : null;
    }

    function position() {
      for (const y of [top + 3, top + 14, top + 30, top + 54]) {
        if (y >= view.innerHeight) break;
        for (const fraction of [0.1, 0.35, 0.65, 0.9]) {
          const x = Math.round(view.innerWidth * fraction);
          const hit = document.caretRangeFromPoint?.(x, y);
          const node = hit?.startContainer;
          if (!node || !document.body.contains(node)) continue;
          const scalar = boundaryScalar(node, hit.startOffset);
          if (scalar === null) continue;
          const point = points[firstIndex(candidate => candidate.scalar < scalar)];
          if (point?.scalar === scalar) {
            const measured = measure(point);
            if (visible(measured)) return measured;
          }
        }
      }
      // A photo may occupy the top of the viewport without a text caret.
      for (const image of document.querySelectorAll('[data-reader-archive-image]')) {
        const point = points.find(candidate => candidate.node === image);
        if (point) {
          const measured = measure(point);
          if (visible(measured)) return measured;
        }
      }
      return null;
    }

    return {
      position,
      restore(scalar) {
        coordinate(scalar, length);
        if (scalar === length) return null;
        const index = firstIndex(point => point.scalar < scalar);
        if (points[index]?.scalar === scalar) return restorePoint(points[index]);
        // Alignment proves that a gap contains whitespace. Restore the first
        // visible point after the gap or the last visible point before it.
        for (let next = index; next < points.length; next++) {
          const position = restorePoint(points[next]);
          if (position) return position;
        }
        for (let previous = index - 1; previous >= 0; previous--) {
          const position = restorePoint(points[previous]);
          if (position) return position;
        }
        return null;
      },
      setTopInset(value) { top = value; },
      selection() {
        const selection = view.getSelection();
        if (!selection || selection.rangeCount !== 1 || selection.isCollapsed) return null;
        const range = selection.getRangeAt(0);
        const startScalar = boundaryScalar(range.startContainer, range.startOffset);
        const endScalar = boundaryScalar(range.endContainer, range.endOffset, true);
        if (startScalar === null || endScalar === null || startScalar >= endScalar) return null;
        return { startScalar, endScalar };
      },
      select(startScalar, endScalar) {
        coordinate(startScalar, length);
        coordinate(endScalar, length);
        const begin = firstIndex(point => point.scalar < startScalar);
        const end = firstIndex(point => point.scalar < endScalar);
        if (begin >= end || points[begin]?.scalar !== startScalar || points[end - 1]?.scalar + 1 !== endScalar) return null;
        const range = document.createRange();
        setBoundary(range, 'setStart', endpoint(points[begin]));
        setBoundary(range, 'setEnd', endpoint(points[end - 1], true));
        const selection = view.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        return this.selection();
      },
      scalarAtElement(element) {
        return points.find(point => element.contains(point.node))?.scalar ?? null;
      },
    };
  }

  Object.defineProperty(window, 'ReaderEbookDom', {
    value: Object.freeze({ create, scalarCount }),
  });
})();
