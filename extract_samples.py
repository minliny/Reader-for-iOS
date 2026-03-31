
import json

with open(r'c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json', 'r', encoding='utf-8') as f:
    book_sources = json.load(f)

target_names = [
    "🎉 当阅读网",
    "🎉 冬日小说",
    "📚 古龙全集"
]

for bs in book_sources:
    name = bs.get('bookSourceName', '')
    if name in target_names:
        print(f'--- {name} ---')
        print(json.dumps(bs, ensure_ascii=False, indent=2))
        print()

