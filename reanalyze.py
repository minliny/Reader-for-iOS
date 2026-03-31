
import json

with open(r'c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json', 'r', encoding='utf-8') as f:
    book_sources = json.load(f)

print('书源重新分类分析（按纠偏规则）')
print('=' * 120)
print()

results = []

for idx, bs in enumerate(book_sources):
    name = bs.get('bookSourceName', '')
    
    has_js = False
    has_login = bool(bs.get('loginUrl'))
    has_java = False
    has_aes = False
    has_css = False
    has_jsonpath = False
    has_replace = False
    has_xpath = False
    
    rules = [
        bs.get('ruleSearch', {}),
        bs.get('ruleBookInfo', {}),
        bs.get('ruleToc', {}),
        bs.get('ruleContent', {}),
    ]
    
    for rule in rules:
        for v in rule.values():
            if not v:
                continue
            s = str(v)
            if '@js:' in s or '&lt;js&gt;' in s:
                has_js = True
            if 'java.' in s:
                has_java = True
            if 'aes' in s.lower() or 'AES' in s:
                has_aes = True
            if '@text' in s or '@href' in s or '@src' in s or '@html' in s or ('.' in s and not '$.' in s and not '@' in s[0]):
                has_css = True
            if '$.' in s or '$[' in s:
                has_jsonpath = True
            if '##' in s and not ('@js:' in s or '&lt;js&gt;' in s):
                has_replace = True
            if '//' in s and not 'http' in s:
                has_xpath = True
    
    has_search = bool(bs.get('searchUrl'))
    has_toc_rule = bool(bs.get('ruleToc', {}))
    has_content_rule = bool(bs.get('ruleContent', {}))
    can_close_loop = has_search and has_toc_rule and has_content_rule
    
    category = 'extended'
    if has_login:
        category = 'login'
    elif has_js:
        category = 'js'
    elif has_java or has_aes:
        category = 'extended'
    else:
        category = 'non_js'
    
    rule_types = []
    if has_css:
        rule_types.append('css')
    if has_jsonpath:
        rule_types.append('jsonpath')
    if has_replace:
        rule_types.append('replace')
    if has_xpath:
        rule_types.append('xpath')
    
    recommend_p0 = category == 'non_js' and can_close_loop and len(rule_types) &gt; 0
    
    results.append({
        'index': idx,
        'name': name,
        'category': category,
        'rule_types': rule_types,
        'can_close_loop': can_close_loop,
        'recommend_p0': recommend_p0,
        'data': bs
    })

total = len(results)
non_js_count = sum(1 for r in results if r['category'] == 'non_js')
js_count = sum(1 for r in results if r['category'] == 'js')
login_count = sum(1 for r in results if r['category'] == 'login')
extended_count = sum(1 for r in results if r['category'] == 'extended')
p0_count = sum(1 for r in results if r['recommend_p0'])

print('一、书源重新分类结果')
print('-' * 120)
print(f'总数: {total}')
print(f'non_js: {non_js_count}')
print(f'js: {js_count}')
print(f'login: {login_count}')
print(f'extended: {extended_count}')
print(f'P0 推荐数: {p0_count}')
print()

print('二、P0 non_js 推荐样本清单（前 12 个）')
print('-' * 120)

p0_candidates = [r for r in results if r['recommend_p0']]

for i, r in enumerate(p0_candidates[:12]):
    status = '✅ 推荐' if r['recommend_p0'] else '❌ 不推荐'
    loop = '✅ 可闭环' if r['can_close_loop'] else '❌ 不可闭环'
    print(f'[{i+1}] {r["name"]}')
    print(f'    index: {r["index"]}')
    print(f'    ruleTypes: {", ".join(r["rule_types"])}')
    print(f'    闭环: {loop}')
    print(f'    推荐: {status}')
    print()

print('三、先落地的 3 个最稳样本')
print('-' * 120)

top3 = p0_candidates[:3]
for i, r in enumerate(top3):
    print(f'[{i+1}] {r["name"]} (index={r["index"]})')
    print(f'    理由: ruleTypes={", ".join(r["rule_types"])}, 可闭环')
    print()

