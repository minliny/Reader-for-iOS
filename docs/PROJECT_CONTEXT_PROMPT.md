你是本项目的 AI 开发代理。

当前项目状态如下（必须继承，不允许回退）：

```yaml
project:
  name: Reader-for-iOS
  architecture: "Core + multi-shell"
  phase: p0_non_js_core_stable
  current_focus: execution_layer_structural_split
  branch: main
  head_commit: "9f4e44bdcf4ed270f9a7ceaf1f9606870e02a31c"

ci_status:
  reader_core_swift_tests:
    run_id: 23979783880
    status: success
  fixture_toc_regression:
    run_id: 23979783875
    status: success

core_modules:
  rule_parser:
    status: stable
    responsibilities:
      - rule_string_parsing
      - selector_extractor_split
      - unknown_extractor_fail_fast
  selector_engine:
    status: stable
    capabilities:
      - selector_semantics
      - descendant_matching
      - child_chain
      - tag_class_id_matching
  css_executor:
    status: stable
    responsibilities:
      - orchestration
      - html_document_parse_entry
      - extraction_dispatch
    capabilities:
      - selector_semantics
      - text/html/href/src/alt extraction
      - unknown_extractor_fail_fast
  fixture_toc_parser:
    status: stable
    guarantees:
      - selector_miss_returns_empty
      - title_miss_returns_empty
      - url_miss_returns_empty
      - count_mismatch_returns_empty
      - singleton_rejected
  toc_item:
    status: stable
    guarantees:
      - invalid_url_kept_raw
      - relative_url_requires_explicit_base
      - title_postprocessing_stable
  http_client:
    status: stable
    guarantees:
      - invalid_url_maps_to_invalid_url

current_structure:
  rule_parsing:
    file: "Core/Sources/ReaderCoreParser/RuleParser.swift"
    status: decoupled
  selector_execution:
    file: "Core/Sources/ReaderCoreParser/SelectorEngine.swift"
    status: decoupled
  extraction:
    file: "Core/Sources/ReaderCoreParser/CSSExecutor.swift"
    status: coupled
  orchestration:
    file: "Core/Sources/ReaderCoreParser/CSSExecutor.swift"
    status: coupled

contracts:
  css_executor_unknown_extractor:
    behavior: fail_fast
    failure_type: RULE_UNSUPPORTED
    expected: "samples/expected/toc/css_executor_unknown_extractor_contract.json"

assets:
  metadata: complete
  expected: complete
  compat_matrix: complete
  regression_summary: complete

next_target:
  module: extraction_layer
  action: split_from_css_executor
  constraints:
    - no_behavior_change
    - no_dsl_extension
    - ci_must_remain_green
    - no_test_modification
    - no_failure_type_addition

rules:
  clean_room: true
  no_gpl_code: true
  no_test_modification: true
  no_failure_type_addition: true
  no_js_login_cookie_expansion: true
```

当前阶段：
- `p0_non_js_core_stable`
- 主线 CI 全绿

已完成：
- CSSExecutor 收敛
- FixtureTocParser 收敛
- TocItem URL 语义收敛
- HTTPClient 错误分类收敛
- RuleParser 已拆分
- SelectorEngine 已拆分

当前结构状态：
- rule parsing：已解耦
- selector execution：已解耦
- extraction：仍在 `CSSExecutor`
- orchestration：仍在 `CSSExecutor`

当前唯一允许的开发方向：
→ 结构拆分（extraction layer）

禁止事项：
- 不扩展 DSL
- 不修改测试
- 不新增 failureType
- 不进入 JS / 登录 / Cookie
- 不回退当前 green contract

下一步唯一目标：
→ 从 `CSSExecutor` 中拆分 extraction layer，保持行为完全不变

附加注意：
- 当前工作区存在未提交的 `samples/docs` 本地资产，不要误回退。
- 当前以仓库内源码、tests、samples、CI 结果为唯一依据，继续遵守 clean-room 原则。

请在此状态下继续执行任务，不要重新分析项目，不要生成新的架构方案。
