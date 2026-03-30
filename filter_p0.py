
import json

with open(r'c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json', 'r', encoding='utf-8') as f:
    book_sources = json.load(f)

print('筛选 P0 non-js 候选（仅 jsonpath/regex/replace，无 CSS）')
print('=' * 120)
print()

p0_candidates = []

for idx, bs in enumerate(book_sources):
    name = bs.get('bookSourceName', '')
    
    has_js = False
    has_java = False
    has_login = bool(bs.get('loginUrl'))
    has_css = False
    has_jsonpath = False
    has_replace = False
    
    rules = [bs.get('ruleSearch', {}), bs.get('ruleBookInfo', {}), 
             bs.get('ruleToc', {}), bs.get('ruleContent', {})]
    
    for rule in rules:
        for v in rule.values():
            if v:
                s = str(v)
                if '@js:' in s or '&lt;js&gt;' in s:
                    has_js = True
                if 'java.' in s:
                    has_java = True
                if '$.' in s or '$[' in s:
                    has_jsonpath = True
                if '##' in s and not ('@js:' in s or '&lt;js&gt;' in s):
                    has_replace = True
                if '@text' in s or '@href' in s or '@src' in s or '.class' in s or '#id' in s:
                    has_css = True
    
    if not has_js and not has_java and not has_login and not has_css and (has_jsonpath or has_replace):
        p0_candidates.append({
            'index': idx,
            'name': name,
            'data': bs,
            'has_jsonpath': has_jsonpath,
            'has_replace': has_replace
        })
        print(f'[{idx}] ✅ {name}')
        print(f'    JSONPath: {has_jsonpath}, Replace: {has_replace}')
        print(f'    Search URL: {bs.get("searchUrl", "")[:120]}')
        print()

print()
print(f'Found {len(p0_candidates)} P0 non-js candidates')
print()

for i, c in enumerate(p0_candidates):
    sample_id = f'p0_non_js_{i+1:03d}'
    print(f'--- Sample: {sample_id} ---')
    print(f'Name: {c["name"]}')
    print('Rule Search:', c['data'].get('ruleSearch', {}))
    print('Rule TOC:', c['data'].get('ruleToc', {}))
    print('Rule Content:', c['data'].get('ruleContent', {}))
    print()

