# Reader for iOS - Claude Code 开发环境配置

## 1. Project Role

**Reader for iOS** 是 **Reader-Core** 的 iOS shell / platform runtime host。

### Reader-Core 负责：
- Parser（解析器）
- DTO（数据传输对象）
- Runtime contracts（运行时契约）
- SecurityGate（安全门控）
- Dry-run（空运行）
- Snapshot / Audit contracts（快照/审计契约）
- Platform adapter protocols（平台适配器协议）
- `ReaderPlatformAdapters` 中的可选平台 adapter

### Reader for iOS 负责：
- SwiftUI App shell（应用外壳）
- 用户授权 UI（用户授权界面）
- Debug Harness（调试工具）
- iOS Simulator / 真机运行宿主
- 调用 Reader-Core / ReaderPlatformAdapters
- 展示 rendered snapshot / audit result（展示渲染后的快照/审计结果）
- **不重复实现 Reader-Core 业务逻辑**

---

## 2. Hard Boundaries（硬边界）

以下规则必须严格遵守：

- **Reader for iOS 不得直接 import ReaderCoreParser 内部实现**
- **Reader for iOS 不得重复实现 Reader-Core parser/runtime business logic**
- **ReaderCoreModels 不得 import WebKit/UIKit**
- **ReaderCoreParser 不得 import WebKit/UIKit**
- **WKWebView 只允许出现在以下位置：**
  - `ReaderPlatformAdapters`
  - `Platforms/iOS`
  - `Debug Harness`
  - 测试/文档中
- **ReaderForIOSApp target 不得直接编译 `../Reader-Core/Core/Sources`**
- **Reader-Core 只能通过 Swift Package dependency 引入**
- **禁止把 Core/Sources 加入 App target sources**

---

## 3. Duplicate Class Risk（重复类风险）

### 问题症状

如果出现以下错误：

```
Class ... WebViewRuntimeHarnessViewModel is implemented in both:
- ReaderCoreModels.framework
- ReaderForIOSApp.app/ReaderForIOSApp.debug.dylib
```

这说明 Reader-Core 源码被重复编译。

### 优先检查项

检查 `project.yml` 中 `targets.ReaderForIOSApp.sources` 是否错误包含：
- `.`（当前目录）
- `..`（父目录）
- `Core`
- `../Reader-Core`
- `../Reader-Core/Core/Sources`

### 正确做法

- App target sources 只包含 `Platforms/iOS` 或 App 自有源码
- Reader-Core 通过 `packages/path` dependency 引入

### 示例：正确配置

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
      - package: ReaderCore
        product: ReaderCoreModels
```

---

## 4. Standard Commands（标准命令）

### 状态检查

```bash
git status --short
git rev-parse HEAD
git log -5 --oneline
git diff --stat
```

### XcodeGen

```bash
xcodegen generate
```

### Xcode project

```bash
xcodebuild -list -project ReaderForIOS.xcodeproj
```

### Simulator

```bash
xcrun simctl list devices available
```

### 构建

```bash
xcodebuild build \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### iOS boundary

```bash
bash scripts/check_ios_boundary.sh
```

### Reader-Core WebView boundary

```bash
cd /Users/minliny/Documents/Reader-Core
bash scripts/check_webview_adapter_boundary.sh
```

---

## 5. WebView Runtime Policy（WebView 运行时策略）

### 真实 WebView 测试需要用户单独授权

#### 允许的测试约束

- Single URL only（仅单个 URL）
- `allowed_host` required（必须指定允许的主机）
- `maxNavigationCount = 1`（最大导航次数为 1）
- `requireHttps = true`（必须 HTTPS）
- No batch request（禁止批量请求）
- No recursion（禁止递归）
- No pagination（禁止分页）
- No chapter batch fetch（禁止批量章节获取）
- No WAF / anti-bot bypass（禁止绕过 WAF/反机器人）
- No auto retry（禁止自动重试）
- No Cookie/Login unless separately authorized（除非单独授权，否则禁止 Cookie/Login）
- No arbitrary JS runtime（禁止任意 JS 运行时）

#### 当前默认测试 URL

```yaml
source_id: qianfanxs_user_provided
source_name: 千帆小说
stage: detail
url: https://www.qianfanxs.com/9/9556
allowed_host: www.qianfanxs.com
```

---

## 6. Commit Policy（提交策略）

- **禁止使用 `git add -A`**
- **始终显式添加文件**
- **禁止提交 `.build`**
- **禁止提交 `DerivedData`**
- **禁止提交生成的构建产物（除非明确需要）**
- **禁止提交可能包含敏感数据的未审查快照**
- **可以提交 `project.yml`**
- **通常不提交生成的 `.xcodeproj`（除非项目策略要求）**

---

## 7. Environment Information（环境信息）

### 工具版本

- Xcode: 26.4.1
- Swift: 6.3.1 (Apple Swift version 6.3.1)
- xcodegen: 2.45.4
- git: 2.50.1
- claude: 2.1.126

### 可用模拟器

- iPhone 17 Pro (Booted)
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

### 当前 HEAD

- Reader for iOS: `193770b6bc74ac7889e8b3c2f04178a600756955`
- Reader-Core: `f3b8e160b6e729c6cedf46e307c4af91b78a07c0`

---

## 8. 如何使用 Claude Code

### 从 Reader for iOS 根目录启动

```bash
cd "/Users/minliny/Documents/Reader for iOS"
claude
```

### 使用自定义命令

启动后可以使用：

```
/ios-dev
```

### 权限建议

建议允许的命令：

```
Bash(git status:*)
Bash(git rev-parse:*)
Bash(git log:*)
Bash(git diff:*)
Bash(find:*)
Bash(ls:*)
Bash(cat:*)
Bash(grep:*)
Bash(swift test:*)
Bash(xcodebuild -list:*)
Bash(xcodebuild build:*)
Bash(xcrun simctl list:*)
Bash(xcodegen generate:*)
Bash(bash scripts/check_ios_boundary.sh:*)
```

建议保留询问或禁止的高风险命令：

```
Bash(rm:*)
Bash(git reset:*)
Bash(git clean:*)
Bash(git push:*)
Bash(curl:*)
Bash(wget:*)
Bash(open:*)
Bash(xcrun simctl erase:*)
Bash(xcrun simctl delete:*)
```

---

## 9. 本轮执行结论

- **真实联网**: 否
- **真实 WebView 执行**: 否
- **project.yml 重复 source 风险**: 已检查，未发现危险 source
- **Reader-Core 通过 package dependency 引入**: 是
- **构建状态**: BUILD SUCCEEDED