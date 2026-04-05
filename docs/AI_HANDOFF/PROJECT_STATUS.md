# 项目状态 (PROJECT_STATUS)

## 项目目标
交付一个本地化、多端可复用的阅读核心能力，兼容 Legado 书源 JSON 主流字段结构与主流程行为。

## 当前路线
统一 Core + 多端壳层，当前阶段以 iOS 先行，先做非 JS 主路径闭环。

---

## 里程碑状态

### v0.4.1 — 当前（2026-04-05 完成）
- ✅ p0_non_js 内核稳定：5 个 fixture smoke 全部 CI 验证通过
- ✅ p1_cookie 首个真实样本执行：wenku8.net 确认 tier C（JS gate）
- ✅ 站点三类分类体系建立（A/B/C tier）
- ✅ ReaderCoreJSRenderer 骨架模块（隔离边界确立）
- ✅ 样本体系扩充至 13 个（10 levelA, 1 levelD, 2 pending isolation, 1 classified only）
- ✅ 恢复点机制（DEV_CHECKPOINT.md + tools/checkpoints/）
- ✅ compat_matrix v0.4.1

**关键里程碑数字：**
- p0 non-js smoke: 5/5 passing
- p1 real samples: 1 executed (level D), 2 pending isolation
- p1 classified only: 1 (js_001 = wenku8.net tier C)

---

### v0.5.0 — 下一轮目标

**进入条件：**
- sample_cookie_002 (qidian.com) 完成真实 isolation run
- sample_login_001 (biquge.com.cn) 完成真实 isolation run
- 两者报告落地，compat_matrix 更新

**必须存在的产物：**
- `samples/reports/latest/fetch_result_sample_cookie_002.yml`
- `samples/reports/latest/fetch_isolation_decision_summary_sample_cookie_002.yml`
- `samples/reports/latest/fetch_result_sample_login_001.yml`
- `samples/reports/latest/fetch_isolation_decision_summary_sample_login_001.yml`
- `compat_matrix.yml` v0.5.0 with actualLevel for cookie_002 and login_001
- `DEV_CHECKPOINT.md` updated

**成功条件：**
- 至少 1 个 p1 样本达到 levelA（isolation 找到 winning step）
- OR 两个样本均确认为 tier C（JS gate）并有对应决策文档

---

## 当前最重要的 3 个下一步

1. **SampleCookie002FetchRunner + SampleCookie002IsolationRunner** — 为 qidian.com 创建 fetch/isolation runner，与 cookie_001 同模式
2. **SampleLogin001FetchRunner + SampleLogin001IsolationRunner** — 为 biquge.com.cn 创建 runner
3. **运行 CI，获取真实 isolation 结果** — 判断 cookie_002 / login_001 的 tier

---

## 当前不允许做的事
- ❌ 把 wenku8.net (sample_cookie_001 / sample_js_001) 重新用 URLSession 调参
- ❌ 修改 A/B/C/D 兼容等级定义
- ❌ 新增 failure taxonomy 一级分类（未经完整流程）
- ❌ 将 ReaderCoreJSRenderer 引入 ReaderCoreParser 或 ReaderCoreNetwork 依赖链
- ❌ 在无 isolation 隔离前将 WKWebView 接入主解析路径
- ❌ 修改 sample_001~005 fixture（已 CI 验证通过，不得随意改动）

---

## 当前阻断点
无。下一步可直接开始 SampleCookie002FetchRunner 创建。

---

## 建议下一位 AI 首先阅读的文件列表

1. `docs/DEV_CHECKPOINT.md` — 执行进度和恢复点
2. `samples/classification/site_access_tiers.yml` — 三类站点定义
3. `samples/classification/sample_tier_mapping.yml` — 当前样本 tier 映射
4. `docs/decisions/js_gate_cloudflare_classification.yml` — wenku8.net DO NOT RETRY 决策
5. `samples/matrix/compat_matrix.yml` — v0.4.1 状态
6. `Core/Sources/SampleCookie001FetchRunner/main.swift` — 参考 fetch runner 实现
7. `Core/Sources/SampleCookie001IsolationRunner/main.swift` — 参考 isolation runner 实现
8. `AGENTS.md` — 项目治理总则

---

## 当前已完成模块
| 模块 | 状态 | CI 状态 |
|------|------|---------|
| ReaderCoreFoundation | ✅ | — |
| ReaderCoreModels | ✅ | ✅ 测试通过 |
| ReaderCoreProtocols | ✅ | — |
| ReaderCoreParser (NonJSParserEngine) | ✅ | ✅ 5 smoke 通过 |
| ReaderCoreNetwork (URLSessionHTTPClient + BasicCookieJar) | ✅ | — |
| ReaderCoreCache | ✅ | — |
| ReaderCoreJSRenderer | ⚗️ 骨架 | — (PoC pending) |
| sample_001~005 smoke runners | ✅ | ✅ 全部 CI 通过 |
| SampleCookie001FetchRunner | ✅ | ✅ CI 通过 |
| SampleCookie001IsolationRunner | ✅ | ✅ CI 通过 |
| SampleCookie002FetchRunner | ⏳ 待创建 | — |
| SampleLogin001FetchRunner | ⏳ 待创建 | — |
