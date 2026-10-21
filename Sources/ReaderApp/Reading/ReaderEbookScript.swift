import Foundation

/// WebKit performs HTML/CSS/selection/layout. This isolated-world bridge only
/// matches its decoded DOM to Core's canonical scalar reference, rejects drift,
/// and transports the reader's position/theme/selection intent.
enum ReaderEbookScript {
    /// Reflowable books use native viewport points. Without this metadata,
    /// WebKit's desktop-width fallback silently scales the configured font.
    /// This changes only the presentation DOM, never the retained archive.
    static let viewport = #"""
(function(){'use strict';
  // Parse and authenticate the original DOM without rendering an entire
  // one-entry MOBI before the document-end Core chapter window is admitted.
  // This owner changes only its own root's inline display property.
  const ownedDocument=document;
  let ownedRoot=null,originalDisplay='',originalPriority='',hadStyle=false,state='holding';
  const ownsRoot=()=>document===ownedDocument&&ownedRoot===ownedDocument.documentElement;
  const hold=()=>{
    if(state!=='holding'||document!==ownedDocument)return false;
    const root=ownedDocument.documentElement;if(!root)return false;
    if(ownedRoot&&ownedRoot!==root)return false;
    if(!ownedRoot){
      ownedRoot=root;hadStyle=root.hasAttribute('style');
      originalDisplay=root.style.getPropertyValue('display');
      originalPriority=root.style.getPropertyPriority('display');
    }
    root.style.setProperty('display','none','important');return true;
  };
  const admission=Object.freeze({
    admitChapter(){
      if(state==='admitted')return ownsRoot();
      if(state!=='holding'||!ownsRoot())return false;
      if(ownedRoot.style.getPropertyValue('display')!=='none'||ownedRoot.style.getPropertyPriority('display')!=='important')return false;
      if(originalDisplay)ownedRoot.style.setProperty('display',originalDisplay,originalPriority);
      else ownedRoot.style.removeProperty('display');
      if(!hadStyle&&ownedRoot.style.length===0)ownedRoot.removeAttribute('style');
      state='admitted';return true;
    },
    block(){
      if(state==='retired'||document!==ownedDocument)return;
      if(!ownedRoot)hold();
      if(ownsRoot())ownedRoot.style.setProperty('display','none','important');
      state='blocked';
    },
    retire(){state='retired';} // Never reveal an unadmitted or another document.
  });
  Object.defineProperty(window,'__readerEbookLayoutAdmission',{value:admission});
  hold();
  const value='width=device-width, initial-scale=1';
  const waiting=new MutationObserver(install);
  function install(){
    if(document!==ownedDocument)return;
    hold();
    const head=document.head||document.querySelector('head');if(!head)return;
    waiting.disconnect();
    const owned=document.createElementNS('http://www.w3.org/1999/xhtml','meta');
    owned.setAttribute('name','viewport');
    const enforce=()=>{
      for(const meta of head.querySelectorAll('meta[name]')){
        if(meta!==owned&&meta.getAttribute('name').toLowerCase()==='viewport')meta.remove();
      }
      if(owned.getAttribute('content')!==value)owned.setAttribute('content',value);
      if(owned.parentNode!==head)head.appendChild(owned);
    };
    const observer=new MutationObserver(enforce);
    observer.observe(head,{childList:true,subtree:true,attributes:true,attributeFilter:['name','content']});
    enforce();
  }
  waiting.observe(document,{childList:true,subtree:true});install();
})();
"""#

    static func bootstrap(configuration: [String: Any]) throws -> String {
        var configuration = configuration
        // Older direct bridge callers supply only the original scalar window.
        // Native scalar views preserve that contract without a whole-flow Array.
        // The production Surface supplies both values from its existing slice.
        if configuration["original"] == nil {
            guard let canonical = configuration["canonical"] as? String,
                  let startValue = configuration["start"] as? NSNumber,
                  let endValue = configuration["end"] as? NSNumber,
                  startValue.doubleValue.isFinite, endValue.doubleValue.isFinite,
                  startValue.doubleValue == Double(startValue.intValue),
                  endValue.doubleValue == Double(endValue.intValue) else { throw ReaderEbookError.invalidDocument }
            let start = startValue.intValue, end = endValue.intValue
            let scalars = canonical.unicodeScalars
            guard start >= 0, end >= start, end <= scalars.count else { throw ReaderEbookError.invalidDocument }
            let lower = scalars.index(scalars.startIndex, offsetBy: start)
            let upper = scalars.index(lower, offsetBy: end - start)
            configuration["original"] = String(scalars[lower..<upper])
        }
        if configuration["scalarCount"] == nil {
            guard let content = configuration["content"] as? String else { throw ReaderEbookError.invalidDocument }
            configuration["scalarCount"] = content.unicodeScalars.count
        }
        let json = try JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys])
        guard let encoded = String(data: json, encoding: .utf8) else { throw ReaderEbookError.invalidDocument }
        return "(function(){'use strict';const config=" + encoded + ";" + body + "})();"
    }

    private static let body = #"""
const send=(kind,value)=>window.webkit.messageHandlers.readerEbook.postMessage({session:config.session,kind,value});
const failure=(stage,error)=>send('failure',{stage,reason:String(error).slice(0,256)});
const admissionDocument=document,documentAdmission=window.__readerEbookLayoutAdmission;
const whitespace=c=>/^\p{White_Space}$/u.test(c);
const significant=text=>{const values=[];let scalar=0;for(const c of text){if(!whitespace(c))values.push({c,scalar});scalar++;}return values;};
let points=[],expected=[],ready=false,lastAnchor=config.offset,userMoving=false,scrollTimer=0,pendingFrame=0,selectionActive=false,pageTurning=false,pageEpoch=0,layoutGeneration=0;
const body=document.body||document.documentElement;
const style=document.createElementNS('http://www.w3.org/1999/xhtml','style');document.head.appendChild(style);
const decodedWalker=()=>document.createTreeWalker(body,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT,{
    acceptNode(node){
      if(node.nodeType===Node.ELEMENT_NODE){
        const tag=node.localName.toLowerCase();
        if(['script','style','template'].includes(tag)||node.hasAttribute('data-reader-overlay'))return NodeFilter.FILTER_REJECT;
        if(['img','image'].includes(tag))return NodeFilter.FILTER_ACCEPT;
        return NodeFilter.FILTER_SKIP;
      }
      return NodeFilter.FILTER_ACCEPT;
    }
  });
const walk=()=>{
  const found=[],walker=decodedWalker();
  let node;
  while((node=walker.nextNode())){
    if(node.nodeType===Node.TEXT_NODE){let unit=0;for(const c of node.data){if(!whitespace(c))found.push({node,start:unit,end:unit+c.length,c});unit+=c.length;}}
    else if(node.getAttribute('src')||node.getAttribute('data-src')||node.getAttribute('href')||node.getAttribute('xlink:href'))found.push({node,start:0,end:1,c:'\uFFFC',image:true});
  }
  return found;
};
const match=(canonical,stage)=>{
  const reference=significant(canonical),actual=walk();
  if(reference.length!==actual.length)throw Error(`canonical-length:${stage}:expected=${reference.length}:actual=${actual.length}`);
  for(let i=0;i<reference.length;i++)if(reference[i].c!==actual[i].c)throw Error(`canonical-text:${stage}:ordinal=${i}:expected=U+${reference[i].c.codePointAt(0).toString(16)}:actual=U+${actual[i].c.codePointAt(0).toString(16)}`);
  return {reference,actual};
};
const lower=(array,value,key)=>{let lo=0,hi=array.length;while(lo<hi){const mid=lo+((hi-lo)>>1);if(array[mid][key]<value)lo=mid+1;else hi=mid;}return lo;};
const endpoint=(point,end=false)=>{
  if(point.image){const parent=point.node.parentNode;return {node:parent,offset:Array.prototype.indexOf.call(parent.childNodes,point.node)+(end?1:0)};}
  return {node:point.node,offset:end?point.end:point.start};
};
const boundary=(array,reference,scalar)=>{
  const index=lower(reference,scalar,'scalar');
  if(index<array.length)return endpoint(array[index]);
  if(array.length)return endpoint(array[array.length-1],true);
  return {node:body,offset:0};
};
const setRange=(range,method,point)=>range[method](point.node,point.offset);
const documentWindow=()=>{
  // Authenticate the entire original entry, including text outside this chapter.
  // Only the two requested DOM/UTF-16 endpoints survive the streaming comparison;
  // full-flow character objects and node-reference arrays are never constructed.
  const reference=config.canonical[Symbol.iterator](),walker=decodedWalker();
  let scalar=0,referenceScalar=0,referenceCount=0,actualCount=0,mismatch='';
  let start=null,end=null,lastNode=null,lastEnd=0,lastImage=false;
  const nextReference=()=>{
    for(let value=reference.next();!value.done;value=reference.next()){
      const index=scalar++;
      if(!whitespace(value.value)){referenceScalar=index;referenceCount++;return value.value;}
    }
    return null;
  };
  const accept=(node,unit,past,c,image=false)=>{
    const expectedCharacter=nextReference();
    if(expectedCharacter!==null){
      if(start===null&&referenceScalar>=config.start)start=endpoint({node,start:unit,end:past,image});
      if(end===null&&referenceScalar>=config.end)end=endpoint({node,start:unit,end:past,image});
      if(!mismatch&&expectedCharacter!==c)mismatch=`canonical-text:document:ordinal=${actualCount}:expected=U+${expectedCharacter.codePointAt(0).toString(16)}:actual=U+${c.codePointAt(0).toString(16)}`;
    }
    actualCount++;lastNode=node;lastEnd=past;lastImage=image;
  };
  let node;
  while((node=walker.nextNode())){
    if(node.nodeType===Node.TEXT_NODE){
      let unit=0;for(const c of node.data){const past=unit+c.length;if(!whitespace(c))accept(node,unit,past,c);unit=past;}
    }else if(node.getAttribute('src')||node.getAttribute('data-src')||node.getAttribute('href')||node.getAttribute('xlink:href'))accept(node,0,1,'\uFFFC',true);
  }
  // Exhaust the canonical iterator even when the DOM ended first. Keep the
  // original length-first failure contract; no Range may mutate the DOM yet.
  while(nextReference()!==null){}
  if(referenceCount!==actualCount)throw Error(`canonical-length:document:expected=${referenceCount}:actual=${actualCount}`);
  if(mismatch)throw Error(mismatch);
  const pastLast=()=>lastNode?endpoint({node:lastNode,start:lastEnd,end:lastEnd,image:lastImage},true):{node:body,offset:0};
  return {start:start||pastLast(),end:end||pastLast()};
};
const restrictChapter=()=>{
  // Keep original semantic ancestors, document styles, tables, lists and links.
  // Range is the browser's native DOM operation, not a second HTML parser.
  document.querySelectorAll('body style,body link[rel~="stylesheet"]').forEach(node=>document.head.appendChild(node.cloneNode(true)));
  const chapter=documentWindow(),range=document.createRange();
  setRange(range,'setStart',chapter.start);
  setRange(range,'setEnd',chapter.end);
  // Range clones partially selected descendants, but deliberately omits its
  // common ancestor. Preserve that semantic chain too (for example a chapter
  // consisting of one p/em, or a slice inside a table cell).
  const ancestors=[];let ancestor=range.commonAncestorContainer;
  if(ancestor.nodeType!==Node.ELEMENT_NODE)ancestor=ancestor.parentElement;
  while(ancestor&&ancestor!==body){ancestors.push(ancestor);ancestor=ancestor.parentElement;}
  let fragment=range.extractContents();
  for(const original of ancestors){const shell=original.cloneNode(false);shell.appendChild(fragment);fragment=shell;}
  body.replaceChildren(fragment);
  const originalMap=match(config.original,'chapter-original');
  // Apply Core's confirmed rule output. The standard Swift diff is supplied
  // as data; no JavaScript regex/replacement engine re-runs business rules.
  for(const edit of config.edits.slice().reverse()){
    const patch=document.createRange();
    setRange(patch,'setStart',boundary(originalMap.actual,originalMap.reference,edit.startScalar));
    const first=lower(originalMap.reference,edit.startScalar,'scalar'),past=lower(originalMap.reference,edit.endScalar,'scalar');
    // End inside the last character actually replaced. Ending before the next
    // character can cross an inline ancestor (em/span/link), causing Range to
    // collapse outside it and silently discard the replacement's semantics.
    const end=past>first?endpoint(originalMap.actual[past-1],true):boundary(originalMap.actual,originalMap.reference,edit.startScalar);
    setRange(patch,'setEnd',end);
    if(patch.startContainer===patch.endContainer&&patch.startContainer.nodeType===Node.TEXT_NODE){
      patch.startContainer.replaceData(patch.startOffset,patch.endOffset-patch.startOffset,edit.text);
    }else{patch.deleteContents();if(edit.text)patch.insertNode(document.createTextNode(edit.text));}
  }
  body.normalize();
  const visible=match(config.content,'chapter-processed');points=visible.actual;expected=visible.reference;
};
const rangeAt=point=>{const range=document.createRange(),start=endpoint(point);range.setStart(start.node,start.offset);range.collapse(true);return range;};
const scalarAt=(node,offset)=>{
  const target=document.createRange();try{target.setStart(node,offset);target.collapse(true);}catch{return null;}
  let lo=0,hi=points.length;
  while(lo<hi){const mid=lo+((hi-lo)>>1);if(rangeAt(points[mid]).compareBoundaryPoints(Range.START_TO_START,target)<0)lo=mid+1;else hi=mid;}
  return lo<expected.length?expected[lo].scalar:config.scalarCount;
};
const restore=scalar=>{
  lastAnchor=Math.max(0,Math.min(config.scalarCount,scalar));
  const index=lower(expected,lastAnchor,'scalar');
  const point=points[Math.min(index,points.length-1)];if(!point){window.scrollTo(0,0);return;}
  let rect;if(point.image)rect=point.node.getBoundingClientRect();else{const range=rangeAt(point);range.setEnd(point.node,point.end);rect=range.getBoundingClientRect();}
  window.scrollTo(0,Math.max(0,window.scrollY+rect.top-config.topInset));
};
const colorAndMetrics=options=>{
  const font=options.fontURL?`@font-face{font-family:ReaderSelectedFace;src:url(${JSON.stringify(options.fontURL)});font-display:block}`:'';
  const selectable=options.longPressSelectText!==false?'text':'none';
  const variations=Object.entries(options.fontVariations||{}).filter(([tag,value])=>/^[\x20-\x7e]{4}$/.test(tag)&&Number.isFinite(value)).map(([tag,value])=>`${JSON.stringify(tag)} ${value}`).join(',')||'normal';
  const family=options.systemFont?'font-family:-apple-system!important;':font?'font-family:ReaderSelectedFace!important;':'';
  const css=`${font}html{background:transparent!important;color-scheme:${options.dark?'dark':'light'}}body{background:transparent!important;color:${options.ink}!important;font-size:${options.fontSize}px!important;line-height:${options.lineHeight}!important;margin:0!important;padding:${options.topInset}px ${options.rightInset}px ${options.bottomInset}px ${options.leftInset}px!important;overflow-wrap:anywhere;writing-mode:horizontal-tb!important}body,body *{-webkit-user-select:${selectable}!important;user-select:${selectable}!important;font-variation-settings:${variations}!important;${family}}body *{color:inherit!important;background-color:transparent!important}body,p,li,dd,td{letter-spacing:${options.letterSpacing}px!important;text-align:${options.alignment}!important}p{margin-block-start:0!important;margin-block-end:${options.paragraphSpacing}px!important;text-indent:${options.firstLineIndentEm}em!important}img,svg,image{max-width:100%!important;height:auto}img[data-reader-missing]{display:block;box-sizing:border-box;min-height:96px;border:1px solid ${options.meta};color:${options.meta};font-size:14px}a{color:inherit}::selection,::highlight(reader-notes),::highlight(reader-follow){background:${options.selection}}${options.reduceMotion?'*,*::before,*::after{animation:none!important;transition:none!important}':''}`;
  const changed=style.textContent!==css||config.layoutToken!==options.layoutToken;if(style.textContent!==css)style.textContent=css;
  Object.assign(config,options);
  if(config.longPressSelectText===false){getSelection()?.removeAllRanges();selectionActive=false;}
  return changed;
};
const visiblePosition=(report=true)=>{
  if(!ready||!userMoving||selectionActive)return;
  for(const y of [config.topInset+4,config.topInset+20,config.topInset+48])for(const x of [0.1,0.5,0.9]){
    const range=document.caretRangeFromPoint(Math.max(config.horizontalInset+2,innerWidth*x),y);
    if(!range||!body.contains(range.startContainer))continue;
    const scalar=scalarAt(range.startContainer,range.startOffset);if(scalar!==null){lastAnchor=scalar;if(report)send('position',scalar);return;}
  }
};
const canonicalRange=(start,end)=>{
  if(start>=end)return null;const range=document.createRange();
  setRange(range,'setStart',boundary(points,expected,start));setRange(range,'setEnd',boundary(points,expected,end));return range;
};
const overlay=document.createElementNS('http://www.w3.org/1999/xhtml','div');overlay.setAttribute('data-reader-overlay','');overlay.setAttribute('aria-hidden','true');
overlay.style.cssText='position:absolute;left:0;top:0;width:0;height:0;pointer-events:none;z-index:2147483000';document.documentElement.appendChild(overlay);
const caret=(x,y)=>document.caretRangeFromPoint(Math.max(1,Math.min(innerWidth-1,x)),Math.max(1,Math.min(innerHeight-1,y)));
const followRange=()=>{
  const ratio=config.automaticHighlightProgress;if(typeof ratio!=='number'||!Number.isFinite(ratio))return null;
  const y=config.topInset+Math.max(1,innerHeight-config.topInset-16)*Math.max(0,Math.min(1,ratio));
  const first=caret(config.leftInset+2,y),last=caret(innerWidth-config.rightInset-2,y);if(!first||!last)return null;
  if(!body.contains(first.startContainer)||!body.contains(last.startContainer))return null;
  const start=scalarAt(first.startContainer,first.startOffset),end=scalarAt(last.startContainer,last.startOffset);
  return start===null||end===null?null:canonicalRange(Math.min(start,end),Math.max(start,end)+1);
};
const paintHighlights=()=>{
  if(!ready)return;
  const ranges=(config.highlights||[]).slice(0,4096).map(value=>canonicalRange(value.start,value.end)).filter(Boolean),follow=followRange();
  if(window.CSS&&CSS.highlights&&typeof Highlight==='function'){
    CSS.highlights.set('reader-notes',new Highlight(...ranges));CSS.highlights.set('reader-follow',new Highlight(...(follow?[follow]:[])));overlay.replaceChildren();return;
  }
  // Older system WebKit uses native Range rectangles. These decorations are
  // outside the book body, never alter its text nodes or scalar coordinate map.
  const fragment=document.createDocumentFragment();let count=0;
  for(const range of [...ranges,...(follow?[follow]:[])])for(const rect of range.getClientRects()){
    if(++count>8192)break;if(rect.width<=0||rect.height<=0)continue;
    const mark=document.createElementNS('http://www.w3.org/1999/xhtml','span');
    mark.style.cssText=`position:absolute;left:${scrollX+rect.left}px;top:${scrollY+rect.top}px;width:${rect.width}px;height:${rect.height}px;background:${config.selection};opacity:.45;pointer-events:none`;
    fragment.appendChild(mark);
  }
  overlay.replaceChildren(fragment);
};
const layout=async()=>{
  const generation=++layoutGeneration;
  if(config.fontURL&&document.fonts){await document.fonts.load(`${config.fontSize}px ReaderSelectedFace`);await document.fonts.ready;}
  await new Promise(resolve=>requestAnimationFrame(resolve));
  if(!ready||generation!==layoutGeneration)return;
  if(!userMoving&&!selectionActive&&!pageTurning)restore(lastAnchor);paintHighlights();send('ready',{fontURL:config.fontURL||'',systemFont:config.systemFont===true,layoutToken:config.layoutToken||''});
};
window.__readerEbook={
  restore(scalar){if(ready){getSelection()?.removeAllRanges();restore(scalar);paintHighlights();}else lastAnchor=scalar;},
  configure(options){const changed=colorAndMetrics(options);if(ready){if(changed)layout().catch(error=>failure('font-layout',error));else paintHighlights();}},
  pageTarget(direction){
    if(!ready||selectionActive)throw Error('page-not-ready');pageTurning=true;const epoch=++pageEpoch;userMoving=false;
    const maximum=Math.max(0,document.documentElement.scrollHeight-innerHeight),current=Math.max(0,scrollY);
    let beginning=current<=.5;
    if(direction<0&&points.length){const first=points[0];let rect;
      if(first.image)rect=first.node.getBoundingClientRect();else{const range=rangeAt(first);range.setEnd(first.node,first.end);rect=range.getBoundingClientRect();}
      // A restored first glyph may need positive native scrollY to align its
      // actual font ascent to topInset. That is still the first content page.
      beginning=beginning||rect.top>=config.topInset-.5;
    }
    if((direction>0&&current>=maximum-.5)||(direction<0&&beginning)){pageTurning=false;return {y:current,end:true,epoch};}
    let target=Math.max(0,Math.min(maximum,current+direction*Math.max(1,innerHeight-16)));
    if(direction>0){
      // Native caret geometry chooses the first line at the viewport boundary;
      // large illustrations still advance by a measured viewport when no text
      // caret can identify a useful boundary.
      const range=caret(config.leftInset+2,innerHeight-16);
      if(range&&body.contains(range.startContainer)){
        const scalar=scalarAt(range.startContainer,range.startOffset),index=scalar===null?points.length:lower(expected,scalar,'scalar');
        if(index<points.length){const point=points[index],rect=point.image?point.node.getBoundingClientRect():rangeAt(point).getBoundingClientRect();
          const measured=current+rect.top-config.topInset;if(measured>current+1)target=Math.min(maximum,measured);}
      }
    }
    return {y:target,end:false,epoch};
  },
  async commitPage(epoch){await new Promise(resolve=>requestAnimationFrame(resolve));if(!ready||!pageTurning||epoch!==pageEpoch)return null;const previous=lastAnchor;userMoving=true;visiblePosition(false);userMoving=false;const scalar=lastAnchor;lastAnchor=previous;return scalar;},
  acknowledgePage(epoch,scalar){if(!ready||!pageTurning||epoch!==pageEpoch)return;lastAnchor=scalar;pageTurning=false;userMoving=false;paintHighlights();},
  cancelPage(){pageEpoch++;pageTurning=false;userMoving=false;},
  inlineImage(id,url){const image=body.querySelector('img[data-reader-inline-id="'+id+'"]');if(image)image.setAttribute('src',url);},
  retire(){ready=false;pageEpoch++;pageTurning=false;layoutGeneration++;clearTimeout(scrollTimer);cancelAnimationFrame(pendingFrame);overlay.remove();documentAdmission?.retire();}
};
document.addEventListener('selectionchange',()=>{
  if(!ready)return;const selection=getSelection();selectionActive=!!selection&&!selection.isCollapsed;
  if(config.longPressSelectText===false){if(selectionActive)selection.removeAllRanges();selectionActive=false;send('selection',null);return;}
  if(!selectionActive){send('selection',null);return;}
  if(!selection.rangeCount)return;const range=selection.getRangeAt(0);
  if(!body.contains(range.startContainer)||!body.contains(range.endContainer))return;
  const start=scalarAt(range.startContainer,range.startOffset),end=scalarAt(range.endContainer,range.endOffset);
  if(start===null||end===null||start>=end)return;
  send('selection',{start,end,text:Array.from(config.content).slice(start,end).join('')});
});
document.addEventListener('click',event=>{
  if(!ready||selectionActive)return;
  if(event.target.closest('a'))return;
  if(config.paged&&(event.clientX<=innerWidth/3||event.clientX>=innerWidth*2/3)){send('page',event.clientX<=innerWidth/3?-1:1);return;}
  if(event.clientX>innerWidth/3&&event.clientX<innerWidth*2/3)send('center',null);
});
for(const event of ['touchstart','wheel','keydown'])document.addEventListener(event,()=>{userMoving=true;send('manual',null);},{passive:true});
window.addEventListener('scroll',()=>{
  if(!userMoving||pageTurning)return;clearTimeout(scrollTimer);scrollTimer=setTimeout(()=>{userMoving=false;},250);
  cancelAnimationFrame(pendingFrame);pendingFrame=requestAnimationFrame(()=>{visiblePosition();paintHighlights();});
},{passive:true});
body.addEventListener('error',event=>{
  const image=event.target;if(image.localName!=='img')return;
  image.setAttribute('data-reader-missing','');if(!image.getAttribute('alt'))image.setAttribute('alt','插图暂不可用');
  if(ready&&!userMoving&&!pageTurning&&!selectionActive)requestAnimationFrame(()=>{restore(lastAnchor);paintHighlights();});
},true);
body.addEventListener('load',event=>{if(['img','image'].includes(event.target.localName)){event.target.removeAttribute('data-reader-missing');if(ready&&!userMoving&&!pageTurning&&!selectionActive)requestAnimationFrame(()=>{restore(lastAnchor);paintHighlights();});}},true);
try{
  document.querySelectorAll('base').forEach(node=>node.remove());
  document.querySelectorAll('img:not([src])[data-src]').forEach(node=>node.setAttribute('src',node.getAttribute('data-src')));
  colorAndMetrics(config);restrictChapter();
  // DOM Range/TreeWalker admission needs no rendered geometry. Reveal only
  // this authenticated chapter before any font-ready/rAF/geometry await.
  if(documentAdmission&&!documentAdmission.admitChapter())throw Error('chapter-display-admission-stale');
  body.querySelectorAll('img').forEach(image=>{if(image.complete&&!image.naturalWidth){image.setAttribute('data-reader-missing','');if(!image.getAttribute('alt'))image.setAttribute('alt','插图暂不可用');}});
  ready=true;
  let inlineIndex=0;body.querySelectorAll('img').forEach(image=>{const source=image.getAttribute('src')||'';if(source.startsWith('data:image/')){const id=String(inlineIndex++);image.setAttribute('data-reader-inline-id',id);send('inlineImage',{id,source});}});
  layout().catch(error=>failure('initial-layout',error));
  window.addEventListener('resize',()=>{if(ready)layout().catch(error=>failure('resize-layout',error));},{passive:true});
}catch(error){
  ready=false;
  if(document===admissionDocument){
    if(documentAdmission)documentAdmission.block();
    else document.documentElement?.style.setProperty('display','none','important');
  }
  failure('canonical-window',error);
}
"""#
}
