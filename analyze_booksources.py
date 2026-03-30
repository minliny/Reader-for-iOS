
#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

def classify_book_source(bs):
    """
    分类书源并提取关键信息
    """
    name = bs.get("bookSourceName", "")
    has_js = False
    has_login = False
    has_cookie = False
    has_java = False
    has_aes = False
    rule_types = set()

    def check_js(s):
        if not s:
            return False
        return "@js:" in s or "&lt;js&gt;" in s

    def check_java(s):
        if not s:
            return False
        return "java." in s

    def check_aes(s):
        if not s:
            return False
        return "aes" in s.lower() or "AES" in s

    if bs.get("loginUrl"):
        has_login = True

    if bs.get("enabledCookieJar"):
        has_cookie = True

    rules = [
        bs.get("ruleSearch", {}),
        bs.get("ruleBookInfo", {}),
        bs.get("ruleToc", {}),
        bs.get("ruleContent", {}),
        bs.get("ruleExplore", {}),
    ]

    for rule in rules:
        for v in rule.values():
            if not v:
                continue
            s = str(v)
            if check_js(s):
                has_js = True
            if check_java(s):
                has_java = True
            if check_aes(s):
                has_aes = True
            if "$." in s or "$[" in s:
                rule_types.add("jsonpath")
            if "##" in s and not check_js(s):
                rule_types.add("replace")
            if re.search(r"regex.*?##", s, re.IGNORECASE):
                rule_types.add("regex")

    category = "extended"
    if has_login:
        category = "login"
    elif has_js:
        category = "js"
    elif has_cookie:
        category = "cookie"
    elif not has_java and not has_aes:
        category = "non_js"

    return {
        "name": name,
        "category": category,
        "has_js": has_js,
        "has_login": has_login,
        "has_cookie": has_cookie,
        "has_java": has_java,
        "has_aes": has_aes,
        "rule_types": sorted(list(rule_types)),
        "recommend_p0": category == "non_js" and len(rule_types) > 0,
    }

def main():
    file_path = Path(r"c:\Users\Administrator\Documents\Reader-for-iOS\docs\design\书源示例.json")
    with open(file_path, "r", encoding="utf-8") as f:
        book_sources = json.load(f)

    results = []
    for i, bs in enumerate(book_sources):
        result = classify_book_source(bs)
        result["index"] = i
        results.append(result)

    print("=" * 120)
    print("书源分类分析结果")
    print("=" * 120)
    print()

    for r in results:
        status = "✅ 推荐 P0" if r["recommend_p0"] else "❌ 不推荐"
        print(f"[{r['index']}] {r['name']}")
        print(f"    分类: {r['category']}")
        print(f"    规则类型: {', '.join(r['rule_types']) or '无'}")
        print(f"    标记: JS={r['has_js']} 登录={r['has_login']} Cookie={r['has_cookie']} Java={r['has_java']} AES={r['has_aes']}")
        print(f"    推荐 P0: {status}")
        print()

    print("-" * 120)
    print("统计:")
    total = len(results)
    non_js = sum(1 for r in results if r["category"] == "non_js")
    recommend_p0 = sum(1 for r in results if r["recommend_p0"])
    print(f"  总书源数: {total}")
    print(f"  non_js: {non_js}")
    print(f"  推荐 P0: {recommend_p0}")

if __name__ == "__main__":
    main()

