# BookSourceStore Concurrency Cleanup Planning

**Date**: 2026-05-09
**Current HEAD**: 6a25beb
**Status**: INVESTIGATION_COMPLETE_PLANNING_ONLY

---

## 一、发现

**警告来源**: 本轮调查发现 NSLock warnings 不在 `BookSourceStore.swift`，而在 **Reader-Core** 的 `MockRuntimeLoginExecutor.swift`。

**实际 warning 位置**:
```
/Users/minliny/Documents/Reader-Core/Core/Sources/ReaderCoreModels/MockRuntimeLoginExecutor.swift
- line 174: warning: instance method 'lock' is unavailable from asynchronous contexts
- line 176: warning: instance method 'unlock' is unavailable from asynchronous contexts
- line 209, 211, 224, 226, 234, 236, 244, 246, 251, 253: similar warnings
共 12 处 warnings
```

**BookSourceStore.swift 分析**:
```swift
public final class BookSourceStore: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [BookSource]?

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
    // ...
}
```

BookSourceStore 已经正确使用 `withLock` + `defer unlock` 模式，**没有 Swift 6 concurrency warnings**。

---

## 二、根因分析

### BookSourceStore（Reader for iOS）

- ✅ 已使用 `withLock` helper
- ✅ 已使用 `defer { lock.unlock() }`
- ✅ 已标记 `@unchecked Sendable`
- ✅ 无 Swift 6 concurrency warnings

### MockRuntimeLoginExecutor（Reader-Core）

- ❌ 在 async context 中直接调用 `lock()` / `unlock()`
- ❌ 未使用 `withCheckedContinuation` 或其他 async-safe 锁定机制
- ⚠️ 需要修复，但位于 Reader-Core，不在本项目范围内

---

## 三、方案对比

### 方案 A：保留 NSLock + withLock helper（BookSourceStore 已是此方案）

- **优点**: 最小改动，性能好，Sendable 兼容
- **风险**: 无，已正确实现
- **消除 warning**: ✅ 是
- **推荐**: ✅ **已实施，无需修改**

### 方案 B：改用 actor（不适合当前场景）

- **优点**: 语言级别并发安全
- **风险**:
  - 需要改变 public API（actor 不能直接用在 async 函数返回值的位置）
  - 影响现有调用方
  - 测试需要重写
- **消除 warning**: ✅ 是
- **推荐**: ❌ 不推荐，架构改动过大

### 方案 C：移除缓存，每次读写文件

- **优点**: 简单，无并发问题
- **风险**: 性能差，每次操作都读文件
- **消除 warning**: ✅ 是
- **推荐**: ❌ 不推荐，性能不可接受

---

## 四、实际警告位置（供记录）

**不在本项目范围**：
- `Reader-Core/Core/Sources/ReaderCoreModels/MockRuntimeLoginExecutor.swift`
- 12 处 Swift 6 concurrency warnings
- 建议在 Reader-Core 项目中修复

**BookSourceStore 状态**：
- ✅ 无 warnings
- ✅ 已正确使用 withLock pattern

---

## 五、修复结果

**本轮是否实施修复**: NO

**原因**:
1. BookSourceStore.swift 没有 Swift 6 concurrency warnings
2. 实际警告在 Reader-Core 的 MockRuntimeLoginExecutor.swift
3. 警告不在本项目范围内

---

## 六、验证结果

| 检查项 | 结果 |
|--------|------|
| BookSourceStore Swift 6 warnings | ✅ 0 warnings |
| ReaderApp build | ⚠️ module resolution issue |
| Reader-Core warnings in build | ❌ 12 warnings in MockRuntimeLoginExecutor |
| boundary check | ✅ PASS |

---

## 七、剩余风险

1. **Reader-Core**: MockRuntimeLoginExecutor.swift 有 12 处 Swift 6 concurrency warnings
2. **Module resolution**: xcodebuild -target 单独构建时模块解析失败（需要通过 scheme 构建）

---

## 八、下一步建议

1. **Reader-Core 项目**: 在 Reader-Core 中修复 MockRuntimeLoginExecutor.swift 的 NSLock usage
2. **本项目**: BookSourceStore 无需修改
3. **如需在本项目添加文档**: 可更新 PLANNING 目录记录本次调查结果

---

*文档更新时间：2026-05-09 19:55*
*调查结论：BookSourceStore 无 Swift 6 warnings，实际警告在 Reader-Core*
