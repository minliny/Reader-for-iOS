# 使用 Claude Code 进行 iOS 开发

## 目录

1. [环境需求](#环境需求)
2. [启动方式](#启动方式)
3. [Claude Code 命令](#claude-code-命令)
4. [权限建议](#权限建议)
5. [project.yml 规则](#projectyml-规则)
6. [Duplicate Class 问题说明](#duplicate-class-问题说明)
7. [WebView Harness 开发流程](#webview-harness-开发流程)
8. [构建命令](#构建命令)
9. [Simulator 运行命令](#simulator-运行命令)
10. [边界检查命令](#边界检查命令)
11. [常见问题排查](#常见问题排查)

---

## 环境需求

### 必要工具

- Xcode 26.4.1+
- Swift 6.3.1+
- xcodegen 2.45.4+
- Git 2.50.1+
- Claude Code 2.1.126+

### 目录结构

```
Reader for iOS/
├── iOS/                    # iOS 源代码
│   ├── App/               # App 入口
│   ├── Features/          # 功能模块
│   ├── Modules/           # 公共模块
│   ├── Shell/             # Shell 集成
│   └── ...
├── project.yml            # XcodeGen 配置
├── ReaderForIOS.xcodeproj # 生成的 Xcode 项目
├── scripts/
│   ├── check_ios_boundary.sh
│   └── check_ios_dev_environment.sh
├── .claude/
│   └── commands/
│       └── ios-dev.md     # 自定义命令
├── CLAUDE.md              # Claude Code 配置
└── docs/
    ├── CLAUDE_CODE_IOS_ENVIRONMENT_SETUP.md
    └── IOS_DEVELOPMENT_WITH_CLAUDE_CODE.md
```

### 依赖关系

- Reader for iOS 依赖 Reader-Core（通过 Swift Package）
- Reader-Core 位于 `../Reader-Core/Core`
- Reader-Core 是只读的，不能在 Reader for iOS 中直接修改

---

## 启动方式

### 1. 从仓库根目录启动 Claude Code

```bash
cd "/Users/minliny/Documents/Reader for iOS"
claude
```

### 2. 确认当前目录

启动后首先检查：

```bash
pwd
```

应该输出：`/Users/minliny/Documents/Reader for iOS`

### 3. 使用自定义命令

```
/ios-dev
```

这将执行 iOS 开发环境全面检查。

---

## Claude Code 命令

### 内置命令

- `/help` - 查看帮助
- `/clear` - 清除会话
- `/permissions` - 管理权限

### 自定义命令

- `/ios-dev` - 执行 iOS 开发环境检查和构建

---

## 权限建议

### 建议允许的命令（只读/构建）

```json
{
  "allow": [
    "Bash(git status:*)",
    "Bash(git rev-parse:*)",
    "Bash(git log:*)",
    "Bash(git diff:*)",
    "Bash(find:*)",
    "Bash(ls:*)",
    "Bash(cat:*)",
    "Bash(grep:*)",
    "Bash(swift test:*)",
    "Bash(xcodebuild -list:*)",
    "Bash(xcodebuild build:*)",
    "Bash(xcrun simctl list:*)",
    "Bash(xcodegen generate:*)",
    "Bash(bash scripts/check_ios_boundary.sh:*)"
  ]
}
```

### 建议保留询问的命令（高风险）

```json
{
  "ask": [
    "Bash(rm:*)",
    "Bash(git reset:*)",
    "Bash(git clean:*)",
    "Bash(git push:*)",
    "Bash(curl:*)",
    "Bash(wget:*)",
    "Bash(open:*)",
    "Bash(xcrun simctl erase:*)",
    "Bash(xcrun simctl delete:*)"
  ]
}
```

### 禁止的命令（危险）

```json
{
  "deny": [
    "Bash(sudo:*)",
    "Bash(mkfs:*)",
    "Bash(mount:*)"
  ]
}
```

---

## project.yml 规则

### 正确配置示例

```yaml
targets:
  ReaderForIOSApp:
    type: application
    sources:
      - path: iOS/App
      - path: iOS/Features
      - path: iOS/Modules
      - path: iOS/Shell
    dependencies:
      - target: ReaderShellValidation
      - target: ReaderAppSupport
      - target: ReaderAppPersistence
      - package: ReaderCore
        product: ReaderCoreModels
```

### 禁止的配置

**危险！以下配置会导致 duplicate class 错误：**

```yaml
# 错误示例 - 不要这样做
targets:
  ReaderForIOSApp:
    sources:
      - path: ../Reader-Core/Core/Sources  # 危险！
      - path: Core                          # 危险！
      - path: .                             # 危险！
```

### 检查项

在修改 `project.yml` 前，务必确认：

1. `ReaderForIOSApp.sources` 不包含 `.`、`..`
2. `ReaderForIOSApp.sources` 不包含 `Core`、`Core/Sources`
3. `ReaderForIOSApp.sources` 不包含 `../Reader-Core`
4. Reader-Core 通过 `packages` + `dependencies` 引入

---

## Duplicate Class 问题说明

### 问题症状

```
Class WebViewRuntimeHarnessViewModel is implemented in both:
- ReaderCoreModels.framework
- ReaderForIOSApp.app/ReaderForIOSApp.debug.dylib
```

### 原因

Reader-Core 源码被编译了两次：
1. 一次作为 Swift Package dependency
2. 一次被直接加入 App target sources

### 解决方法

1. 检查 `project.yml` 中 `ReaderForIOSApp.sources`
2. 移除所有危险路径（见上一节）
3. 确保 Reader-Core 只通过 package dependency 引入
4. 运行 `xcodegen generate` 重新生成项目
5. 清理 DerivedData：`xcodebuild clean`

### 验证修复

```bash
xcodegen generate
xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp
```

如果构建成功且没有 duplicate class 警告，说明修复正确。

---

## WebView Harness 开发流程

### 当前架构

```
Reader for iOS (iOS App)
    └── ReaderShellValidation.framework
            └── ReaderCore (Swift Package)
                ├── ReaderCoreModels
                ├── ReaderCoreParser
                ├── ReaderCoreNetwork
                └── ReaderPlatformAdapters

Platforms/iOS/Debug/
    └── WebViewRuntimeHarness/  (Debug Harness)
            └── WKWebView (仅此处允许)
```

### 开发原则

1. **WKWebView 只允许在 Debug Harness 中使用**
2. **ReaderCoreModels/ReaderCoreParser 不得 import WebKit/UIKit**
3. **真实 WebView 测试需要用户单独授权**

### 测试约束（未授权时）

- Single URL only
- `allowed_host` required
- `maxNavigationCount = 1`
- `requireHttps = true`
- No batch request
- No recursion
- No pagination
- No chapter batch fetch
- No WAF/anti-bot bypass
- No auto retry

---

## 构建命令

### XcodeGen 生成项目

```bash
xcodegen generate
```

### 构建 iOS App

```bash
xcodebuild build \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 清理后重新构建

```bash
xcodebuild clean
xcodegen generate
xcodebuild build \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 仅构建（跳过清理）

```bash
xcodebuild build \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet
```

---

## Simulator 运行命令

### 列出可用模拟器

```bash
xcrun simctl list devices available
```

### 当前可用模拟器

- iPhone 17 Pro (Booted) - 推荐
- iPhone 17 Pro Max
- iPhone 17e
- iPhone Air
- iPhone 17
- iPad Pro 13-inch (M5)
- iPad Pro 11-inch (M5)
- iPad mini (A17 Pro)
- iPad Air 13-inch (M4)
- iPad Air 11-inch (M4)
- iPad (A16)

### 运行 App（在模拟器中）

构建成功后，可以在 Xcode 中选择模拟器点击 Run，或使用：

```bash
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

---

## 边界检查命令

### iOS Boundary 检查

检查 Reader for iOS 是否遵守 iOS/Core 边界：

```bash
bash scripts/check_ios_boundary.sh
```

### Reader-Core WebView Boundary 检查

检查 Reader-Core 是否正确隔离 WebView：

```bash
cd /Users/minliny/Documents/Reader-Core
bash scripts/check_webview_adapter_boundary.sh
cd "/Users/minliny/Documents/Reader for iOS"
```

### 环境检查脚本

```bash
bash scripts/check_ios_dev_environment.sh
```

---

## 常见问题排查

### Q: xcodegen 生成失败

**A:** 检查 `project.yml` 语法：

```bash
xcodegen generate --spec project.yml
```

确认没有重复的 target 名称或路径错误。

### Q: xcodebuild -list 无法识别项目

**A:** 重新生成项目：

```bash
xcodegen generate
xcodebuild -list -project ReaderForIOS.xcodeproj
```

### Q: 出现 duplicate class 错误

**A:** 见「Duplicate Class 问题说明」章节。

### Q: 构建成功但运行时崩溃

**A:** 检查：
1. Framework 是否正确嵌入：`codesign -dvv ReaderForIOSApp.app`
2. Simulator 是否支持所需功能
3. 查看控制台日志获取详细信息

### Q: 模拟器无法启动

**A:** 重置模拟器：

```bash
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl erase "iPhone 17 Pro"
```

### Q: 如何确认项目干净？

```bash
git status --short
git rev-parse HEAD
git diff --stat
```

确认没有意外的修改。

---

## 附录：CLAUDE.md 配置参考

完整的 CLAUDE.md 配置请见项目根目录的 `CLAUDE.md` 文件，包含：

1. Project role
2. Hard boundaries
3. Duplicate class risk
4. Standard commands
5. WebView runtime policy
6. Commit policy
7. Environment information
8. 如何使用 Claude Code