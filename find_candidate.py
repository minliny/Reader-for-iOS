
import json

with open(r'c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json', 'r', encoding='utf-8') as f:
    book_sources = json.load(f)

# 寻找具备完整 search/toc/content 能力的 non_js 样本
candidates = []
for bs in book_sources:
    name = bs.get('bookSourceName', '')
    if name in ["🎉 当阅读网", "🎉 冬日小说", "📚 古龙全集"]:
        continue
    
    # 检查是否具备完整主链路
    has_search = bool(bs.get('ruleSearch') and bs.get('searchUrl'))
    has_toc = bool(bs.get('ruleToc'))
    has_content = bool(bs.get('ruleContent'))
    has_js = bool(bs.get('ruleJs') or bs.get('loginUrl') or bs.get('jsLib'))
    
    if has_search and has_toc and has_content and not has_js:
        candidates.append({
            'name': name,
            'url': bs.get('bookSourceUrl'),
            'ruleTypes': []
        })

print(f"找到 {len(candidates)} 个候选样本：")
for i, c in enumerate(candidates[:5]):
    print(f"{i+1}. {c['name']} - {c['url']}")
