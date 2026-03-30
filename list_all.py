
import json

with open(r'c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json', 'r', encoding='utf-8') as f:
    book_sources = json.load(f)

print('书源完整列表（65个）')
print('=' * 120)
for idx, bs in enumerate(book_sources):
    name = bs.get('bookSourceName', '')
    print(f'[{idx}] {name}')

