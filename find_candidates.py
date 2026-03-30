
import json

with open(r'c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json', 'r', encoding='utf-8') as f:
    book_sources = json.load(f)

print(f'Total book sources: {len(book_sources)}')
print()

candidates = []

for idx, bs in enumerate(book_sources):
    name = bs.get('bookSourceName', '')
    
    has_js = False
    has_java = False
    has_login = bool(bs.get('loginUrl'))
    
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
    
    if not has_js and not has_java and not has_login:
        candidates.append({
            'index': idx,
            'name': name,
            'data': bs
        })
        print(f'[{idx}] ✅ {name}')

print()
print(f'Found {len(candidates)} non-JS candidates')
print()

for c in candidates[:10]:
    print(f'--- {c["name"]} ---')
    print(f'Search URL: {c["data"].get("searchUrl", "")[:100]}...')
    print(f'Rule Search: {c["data"].get("ruleSearch", {})}')
    print()

