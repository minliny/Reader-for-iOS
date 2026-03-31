# 《样本库规范与兼容矩阵》AI 开发版 v1

> 用途：本文件不是面向人类讨论的说明稿，而是面向 AI 开发代理、代码生成代理、测试代理、审查代理的执行输入文档。  
> 使用方式：后续统一整理时，可将本文件与《项目立项边界》《书源兼容规范》《能力支持矩阵》《工程门禁与回归规则》一起作为 AI 上下文输入。  
> 文档目标：让 AI 明确知道“要生成什么、按什么格式生成、如何验收、哪些不能做”。

---

# 0. 文档角色定义

本文件用于定义以下内容：

- 样本库目录结构
- 样本元信息结构
- 兼容矩阵数据结构
- 失败分类结构
- 回归输出结构
- 阶段门槛
- AI 在开发、测试、修复、审查时必须遵守的规则

本文件不用于：

- 讨论产品方向
- 讨论 UI 方案
- 讨论商业模式
- 推导许可证结论

---

# 1. AI 任务目标

AI 在阅读本文件后，应能完成以下任务：

1. 创建样本库目录结构
2. 为样本生成元信息文件模板
3. 生成 `compat_matrix.yml` 初版
4. 生成 `failure_taxonomy.yml` 初版
5. 生成 PoC 样本清单模板
6. 编写样本回归脚本
7. 编写兼容矩阵统计脚本
8. 在 PR 中输出统一格式的回归摘要

---

# 2. 强制约束

## 2.1 不可违反的约束

AI 必须遵守以下规则：

- 不得直接复制、翻译、改写外部 GPL 实现代码
- 不得生成与本规范冲突的数据结构
- 不得跳过样本元信息文件
- 不得生成无法映射到兼容矩阵的样本
- 不得修改兼容等级定义
- 不得新增失败分类而不更新分类配置
- 不得只给人类说明，不给结构化输出

## 2.2 输出风格约束

AI 输出必须优先采用以下形式：

- YAML
- JSON
- 表格
- 目录树
- 字段清单
- 任务清单
- 模板文件

AI 输出应尽量避免：

- 大段泛化说明
- 空洞建议
- 没有字段定义的描述性文字
- 只有方向没有落地结构

---

# 3. 目录结构规范

AI 生成样本库时，必须遵循以下目录结构：

```text
samples/
  booksources/
    p0_non_js/
    p1_js/
    p1_login/
    p1_cookie/
    p2_extended/
  metadata/
    p0_non_js/
    p1_js/
    p1_login/
    p1_cookie/
    p2_extended/
  fixtures/
    html/
    json/
    text/
    redirects/
  expected/
    search/
    toc/
    content/
  reports/
    latest/
    history/
  matrix/
    compat_matrix.yml
    failure_taxonomy.yml
```

## 3.1 目录语义

- `booksources/`：书源 JSON 文件
- `metadata/`：与书源一一对应的样本元信息文件
- `fixtures/`：离线 HTTP 响应、页面快照、JSON 响应、文本响应
- `expected/`：预期解析结果
- `reports/`：回归报告输出
- `matrix/`：兼容矩阵与失败分类配置

## 3.2 一一对应规则

AI 必须保证：

- 每个 `booksources/*.json` 样本必须有对应 `metadata/*.yml`
- 每个样本必须可关联 0 到多个 fixture
- 每个可回归样本必须有关联的 expected 输出或降级预期

---

# 4. 文件命名规范

AI 生成文件名时必须使用以下模式：

```text
[priority]_[category]_[siteTag]_[featureTag]_[index]
```

示例：

```text
p0_nonjs_sitea_html_001.json
p0_nonjs_sitea_html_001.yml
p1_js_siteb_search_002.json
p1_login_sitec_cookie_003.yml
```

## 4.1 字段定义

- `priority`: `p0` / `p1` / `p2`
- `category`: `nonjs` / `js` / `login` / `cookie` / `extended`
- `siteTag`: 站点标识，简短稳定，不使用空格
- `featureTag`: 主特征标签，如 `html` / `jsonapi` / `search` / `toc` / `content`
- `index`: 三位流水号，如 `001`

---

# 5. 样本元信息 Schema

AI 必须为每个样本生成元信息文件，推荐 YAML。

## 5.1 强制字段

```yaml
sampleId: string
sampleFile: string
priority: enum[p0, p1, p2]
category: enum[non_js, js, login, cookie, extended]
sourceType: enum[real, trimmed, synthetic]
title: string
siteTag: string
featureTags: string[]
ruleTypes: enum[CSS, XPath, JSONPath, Regex, Replace, Header, Cookie, JS][]
expectedLevel: enum[A, B, C, D]
mustPassStage: enum[poc, mvp, phase2, backlog]
blocking: boolean
requiresLogin: boolean
requiresCookieJar: boolean
requiresCustomHeader: boolean
requiresJs: boolean
fixtureFiles: string[]
expectedOutput:
  search: string | null
  toc: string | null
  content: string | null
degradeExpectation: string | null
knownFailureType: string | null
owner: string
notes: string
```

## 5.2 样本元信息示例

```yaml
sampleId: SAMPLE-P0-NONJS-001
sampleFile: samples/booksources/p0_non_js/p0_nonjs_sitea_html_001.json
priority: p0
category: non_js
sourceType: real
title: SiteA 基础 HTML 主链路样本
siteTag: sitea
featureTags:
  - html
  - search
  - toc
  - content
ruleTypes:
  - CSS
  - Regex
  - Replace
expectedLevel: A
mustPassStage: poc
blocking: true
requiresLogin: false
requiresCookieJar: false
requiresCustomHeader: true
requiresJs: false
fixtureFiles:
  - samples/fixtures/html/sitea_search.html
  - samples/fixtures/html/sitea_toc.html
  - samples/fixtures/html/sitea_content.html
expectedOutput:
  search: samples/expected/search/sitea_search_expected.json
  toc: samples/expected/toc/sitea_toc_expected.json
  content: samples/expected/content/sitea_content_expected.json
degradeExpectation: null
knownFailureType: null
owner: core-parser
notes: PoC 必过样本
```

---

# 6. 样本分类规则

AI 在新增样本时必须按下列逻辑分类：

## 6.1 category 判定

### `non_js`
满足以下条件：
- 不依赖 `jsLib`
- 不依赖 `loginCheckJs`
- 不依赖 `coverDecodeJs`
- 搜索、目录、正文可由非 JS 规则完成

### `js`
满足以下任一条件：
- 包含 `jsLib`
- 主流程规则执行依赖 JS
- 输出清洗依赖 JS
- 封面解密依赖 JS

### `login`
满足以下任一条件：
- 需要登录后访问
- 包含 `loginUrl`
- 匿名状态与登录状态行为不同

### `cookie`
满足以下任一条件：
- 依赖 Cookie Jar
- 依赖 Header / Referer / UA / Origin
- 访问策略对会话状态敏感

### `extended`
满足以下任一条件：
- 属于二期或后续能力
- 当前仅观察，不纳入首版必须支持

---

# 7. 兼容等级定义

AI 不得自行扩展或修改兼容等级，只能使用以下四级：

## 7.1 A
- 导入成功
- 搜索成功
- 目录成功
- 正文成功
- 输出与预期一致
- 不依赖人工修正

## 7.2 B
- 主链路可运行
- 某些增强能力被降级
- 不影响基础阅读流程

## 7.3 C
- 可导入
- 可识别问题
- 可提示失败原因
- 不崩溃
- 无法完整执行主链路

## 7.4 D
- 无法导入
- 无法解析核心规则
- 无法安全降级
- 或出现阻断级错误

---

# 8. 失败分类 Schema

AI 必须只使用下面定义的一级失败分类。若确需新增，必须同时更新 `failure_taxonomy.yml`。

## 8.1 一级失败分类枚举

```yaml
failureTypes:
  - JSON_INVALID
  - FIELD_MISSING
  - RULE_INVALID
  - RULE_UNSUPPORTED
  - SEARCH_FAILED
  - TOC_FAILED
  - CONTENT_FAILED
  - NETWORK_POLICY_MISMATCH
  - COOKIE_REQUIRED
  - LOGIN_REQUIRED
  - JS_DEGRADED
  - JS_UNSUPPORTED
  - OUTPUT_MISMATCH
  - CRASH
```

## 8.2 二级失败原因示例

```yaml
RULE_INVALID:
  - invalid_css_selector
  - invalid_xpath_expression
  - invalid_jsonpath_expression
  - invalid_regex_expression

NETWORK_POLICY_MISMATCH:
  - missing_header
  - missing_referer
  - invalid_user_agent
  - redirect_not_handled

OUTPUT_MISMATCH:
  - search_result_count_mismatch
  - toc_order_mismatch
  - content_missing_paragraph
  - content_cleaning_mismatch
```

---

# 9. 兼容矩阵 Schema

AI 必须生成 `samples/matrix/compat_matrix.yml`，其结构至少应包含以下字段：

```yaml
version: string
generatedAt: string
summary:
  totalSamples: number
  levelA: number
  levelB: number
  levelC: number
  levelD: number
  passRate: number
  degradeRate: number
  failRate: number
  p0PassRate: number
  pocPassRate: number
samples:
  - sampleId: string
    priority: enum[p0, p1, p2]
    category: enum[non_js, js, login, cookie, extended]
    ruleTypes: string[]
    requiresLogin: boolean
    requiresCookieJar: boolean
    requiresJs: boolean
    expectedLevel: enum[A, B, C, D]
    actualLevel: enum[A, B, C, D]
    failureType: string | null
    errorCode: string | null
    blocking: boolean
    notes: string
```

## 9.1 单条记录示例

```yaml
- sampleId: SAMPLE-P0-NONJS-001
  priority: p0
  category: non_js
  ruleTypes:
    - CSS
    - Regex
    - Replace
  requiresLogin: false
  requiresCookieJar: false
  requiresJs: false
  expectedLevel: A
  actualLevel: A
  failureType: null
  errorCode: null
  blocking: true
  notes: PoC 主链路通过
```

---

# 10. expected 输出结构

AI 生成 expected 结果文件时，必须分别按 `search` / `toc` / `content` 输出。

## 10.1 search expected

```json
{
  "items": [
    {
      "name": "string",
      "author": "string|null",
      "detailUrl": "string"
    }
  ]
}
```

## 10.2 toc expected

```json
{
  "chapters": [
    {
      "title": "string",
      "url": "string",
      "index": 1
    }
  ]
}
```

## 10.3 content expected

```json
{
  "title": "string|null",
  "content": "string",
  "nextPage": "string|null"
}
```

## 10.4 对比容忍规则

AI 在编写回归对比逻辑时必须支持：

- 忽略无意义空白差异
- 忽略动态时间戳字段
- 忽略随机参数差异
- 不允许正文主内容缺失
- 不允许目录顺序错误
- 不允许搜索主结果结构错误

---

# 11. 阶段门槛

## 11.1 PoC 门槛

```yaml
pocGate:
  pocPassRate: 1.0
  allowCrash: false
  requireTraceableFailure: true
  requiredCategories:
    - non_js
```

## 11.2 MVP 门槛

```yaml
mvpGate:
  p0PassRate: 0.90
  nonJsPassRate: 0.70
  jsMustBeTraceable: true
  jsMustNotCrash: true
  loginBoundaryMustBeDefined: true
  cookieBoundaryMustBeDefined: true
```

## 11.3 发布候选门槛

```yaml
releaseGate:
  p0PassRate: 0.95
  allowBlockingFailure: false
  requireUpdatedMatrix: true
  requireFailureTopItemsReviewed: true
```

---

# 12. AI 可执行任务拆分

AI 在开发阶段应优先按以下顺序执行：

## 12.1 Task-01 创建样本库骨架
输出：
- 目录树
- 空目录初始化文件
- `compat_matrix.yml` 初版
- `failure_taxonomy.yml` 初版

## 12.2 Task-02 创建样本元信息模板
输出：
- `sample_template.yml`
- 命名规则说明
- metadata 校验规则

## 12.3 Task-03 创建 expected 模板
输出：
- `search_expected_template.json`
- `toc_expected_template.json`
- `content_expected_template.json`

## 12.4 Task-04 创建 PoC 样本清单
输出：
- 10 个 P0 非 JS 样本清单
- 每个样本的 category / ruleTypes / mustPassStage / blocking 标记

## 12.5 Task-05 编写样本校验脚本
输出：
- 检查 `booksources` 与 `metadata` 是否一一对应
- 检查 metadata 必填字段是否完整
- 检查 expected 输出文件是否缺失
- 检查 `sampleId` 是否重复

## 12.6 Task-06 编写回归统计脚本
输出：
- 读取样本执行结果
- 计算 A/B/C/D 数量
- 计算 P0 通过率
- 计算 PoC 必过样本通过率
- 输出报告摘要

---

# 13. AI 审查清单

AI 在修复兼容性问题或提交 PR 时，必须检查：

- 是否绑定至少 1 个样本
- 是否说明修复前失败类型
- 是否说明修复后预期变化
- 是否更新 compat_matrix
- 是否影响 P0 样本通过率
- 是否引入新的失败类型
- 是否需要更新 expected 输出

---

# 14. PR 输出模板

AI 在提交开发结果时，必须尽量按以下格式输出：

```text
关联样本：
- SAMPLE-XXX

改动范围：
- metadata
- fixtures
- expected
- regression script
- matrix

修复前失败类型：
- CONTENT_FAILED

修复后预期：
- actualLevel: C -> A

回归摘要：
- totalSamples:
- levelA:
- levelB:
- levelC:
- levelD:
- p0PassRate:

是否更新矩阵：yes/no
是否新增失败类型：yes/no
是否需要人工补充样本：yes/no
```

---

# 15. AI 禁止事项

AI 在本模块开发中禁止：

- 只输出概念，不输出文件模板
- 直接省略 metadata 层
- 将不同失败场景混写为一个 failureType
- 用自然语言代替结构化矩阵字段
- 只修复单样本而不说明是否影响全量样本
- 新增字段但不说明用途和兼容性影响
- 修改 A/B/C/D 判定标准

---

# 16. 建议统一纳入 AI 上下文的文件

后续统一整理时，建议把以下文件一起喂给 AI：

1. 《项目立项边界》
2. 《书源兼容规范》
3. 《能力支持矩阵》
4. 《工程门禁与回归规则》
5. 《样本库规范与兼容矩阵》AI 开发版
6. 后续的《JS / 登录 / Cookie 策略》AI 开发版
7. 后续的《错误码与失败分类字典》AI 开发版

---

# 17. 下一步推荐动作

下一步应继续生成以下三份 AI 输入资产：

1. `compat_matrix.yml` 初版
2. `failure_taxonomy.yml` 初版
3. `sample_template.yml` 初版

完成这三项后，本文件才真正从“AI 可读”进入“AI 可执行”。

