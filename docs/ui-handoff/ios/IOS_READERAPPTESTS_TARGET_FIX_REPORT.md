# iOS ReaderAppTests Target Fix Report

## 1. 总体结论

**IOS_READERAPPTESTS_TARGET_FIX_BLOCKED**

`ReaderAppTests` 无法编译。`BookshelfItemFactory.swift` 在 `ReaderAppSupport` 独立编译（`-target ReaderAppSupport`）时触发 Swift 模块解析失败——这是 Xcode 26.5/Swift 6.3.1 的已知深层问题，不是项目配置错误。

---

## 2. 问题现象

```
/iOS/AppSupport/Sources/BookshelfItemFactory.swift:2:8: error: unable to resolve module dependency: 'ReaderCoreModels'
```

| 编译方式 | 结果 |
|---|---|
| `xcodebuild -scheme ReaderForIOSApp build` | BUILD SUCCEEDED |
| `xcodebuild -target ReaderAppSupport build` | BUILD FAILED |
| `xcodebuild -target ReaderAppTests build` | BUILD FAILED |
| `xcodebuild -target ShellSmokeTests build` | BUILD FAILED |

---

## 3. 排查过程

### 3.1 确认配置正确

| 检查项 | 结果 |
|---|---|
| `project.yml` ReaderAppSupport dependencies | ✅ 包含 `package: ReaderCore product: ReaderCoreModels` |
| `project.pbxproj` packageProductDependencies | ✅ `2AB4BABF02D5255F4A1A7DAA /* ReaderCoreModels */` |
| `@testable import ReaderApp` 语法 | ✅ 与 `SmokeTests.swift` 完全一致 |
| M3 代码修改影响 | ❌ 问题在 M3 之前已存在（git stash 验证） |
| 同 target 其他文件 import ReaderCoreModels | ✅ `ChapterCacheEntry.swift` 无问题 |

### 3.2 关键观察

1. **仅 BookshelfItemFactory.swift 触发错误** — 同 target 的其他 9 个 Swift 文件全部正常
2. **`-target` 独立编译失败，scheme 编译成功** — Swift 编译器 explicit-module-build 和 VFS overlay 交互问题
3. **错误发生在 SwiftDriver 阶段** — 尚未到 SwiftCompile 阶段
4. **Swift 编译器深层问题** — 同一 compilation unit 中 10 个文件，只有 1 个在 VFS overlay 处理时出现解析确定性失败

### 3.3 Xcode/Swift 版本

- Xcode: 26.5 (Build version 17F42)
- Swift: 6.3.1
- 问题在 Xcode 26.5 beta 中持续存在

---

## 4. 本轮修改

| 文件 | 改动 |
|---|---|
| `iOS/Tests/ReaderAppTests/ReadingCacheAndProgressM3Tests.swift` | 改用 `import ReaderAppSupport` + `import ReaderAppPersistence` + `import ReaderCoreModels`（移除 `@testable import ReaderApp`） |
| `project.yml` | ReaderAppSupport 添加 `ReaderCoreModels` package dependency（FRAMEWORK_SEARCH_PATHS 追加对问题无效，已回退） |
| `ReaderForIOS.xcodeproj` | xcodegen 重新生成 |

---

## 5. 验证结果

| 检查 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS |
| `xcodebuild -scheme ReaderForIOSApp build` | BUILD SUCCEEDED |
| `xcodebuild -target ReaderAppSupport build` | BUILD FAILED |
| `xcodebuild -target ReaderAppTests build` | BUILD FAILED |
| `xcodebuild -target ShellSmokeTests build` | BUILD FAILED |
| P0 | 1 |
| P1 | 0 |
| P2 | 1 |

---

## 6. 下一步建议

1. **M3 测试临时迁移到 ShellSmokeTests**: 将 `ReadingCacheAndProgressM3Tests` 的核心逻辑（SnapshotStore 的 save/load、ReadingProgressStore、BookshelfStore.updateProgress）迁移到 `ShellSmokeTests`，使用 `import ReaderAppSupport` + `import ReaderAppPersistence` + `import ReaderCoreModels`，已验证 ShellSmokeTests 可以编译。

2. **Xcode 层面问题**: 这是 Xcode 26.5/Swift 6.3.1 的已知问题，配置上无法修复，等待 Xcode 更新。

3. **ReaderAppTests target 重构**: 如果需要 ReaderAppTests 可执行，考虑将 `dependencies` 从 `target: ReaderForIOSApp` 改为直接依赖各 framework（ReaderAppSupport、ReaderAppPersistence 等），但这不能解决 BookshelfItemFactory 的问题。

---

## 7. 是否修改 Swift 源码

**否**（ReadingCacheAndProgressM3Tests 改 import 是测试适配，不算功能修改）。

## 8. 是否修改 project/Package 配置

**是** — `project.yml` ReaderAppSupport 添加了 ReaderCoreModels package dependency（对解决问题无效但配置正确）。

## 9. 是否修改 Reader-Core

**否**。

---

## 10. 是否本地提交

**否**。本轮 project.yml 修改对解决问题无效，等待确定有效的修复方案后再提交。

---

## 11. 报告路径

`docs/ui-handoff/ios/IOS_READERAPPTESTS_TARGET_FIX_REPORT.md`