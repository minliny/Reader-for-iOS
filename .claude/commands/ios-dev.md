---
description: iOS 开发环境检查和构建命令
---
# iOS 开发环境检查和构建命令

## 描述

执行 Reader for iOS 项目的 iOS 开发环境检查，包括：
1. 状态检查（git、HEAD）
2. project.yml / xcodeproj 检查
3. duplicate class 风险检查
4. iOS boundary 检查
5. xcodegen generate
6. xcodebuild build
7. 输出中文报告

## 前提条件

**必须从 `/Users/minliny/Documents/Reader for iOS` 启动 Claude Code**

如果 pwd 不对，先停止并提示用户。

## 约束

- 不得直接修改 Reader-Core Parser
- 不得重复编译 Reader-Core sources
- 不得执行真实 WebView URL，除非用户明确授权
- 不得使用 `git add -A`
- 不得提交 .build、DerivedData

## 工具

- Bash(git status:*)
- Bash(git rev-parse:*)
- Bash(git log:*)
- Bash(git diff:*)
- Bash(find:*)
- Bash(ls:*)
- Bash(cat:*)
- Bash(grep:*)
- Bash(swift test:*)
- Bash(xcodebuild -list:*)
- Bash(xcodebuild build:*)
- Bash(xcrun simctl list:*)
- Bash(xcodegen generate:*)
- Bash(bash scripts/check_ios_boundary.sh:*)

## 执行步骤

### Step 1: 状态检查

```bash
cd "/Users/minliny/Documents/Reader for iOS"
pwd
git status --short
git rev-parse HEAD
git log -5 --oneline
git branch --show-current
git diff --stat
```

### Step 2: project.yml / xcodeproj 检查

```bash
cat project.yml
xcodebuild -list -project ReaderForIOS.xcodeproj
```

### Step 3: Duplicate class 风险检查

检查 `project.yml` 中 `targets.ReaderForIOSApp.sources` 是否包含危险路径：
- `.` / `..`
- `Core` / `Core/Sources`
- `../Reader-Core`
- `../Reader-Core/Core/Sources`

```bash
grep -A 20 "ReaderForIOSApp:" project.yml
```

### Step 4: iOS boundary 检查

```bash
bash scripts/check_ios_boundary.sh
```

### Step 5: Reader-Core WebView boundary 检查

```bash
cd /Users/minliny/Documents/Reader-Core
bash scripts/check_webview_adapter_boundary.sh
cd "/Users/minliny/Documents/Reader for iOS"
```

### Step 6: xcodegen generate（如需要）

```bash
xcodegen generate
```

### Step 7: xcodebuild build

```bash
xcodebuild build \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Step 8: Simulator 检查（如构建失败）

```bash
xcrun simctl list devices available
```

## 输出格式

最后输出中文报告，包含：

```
## iOS 开发环境检查报告

### 环境状态
- 当前目录: /Users/minliny/Documents/Reader for iOS
- HEAD: [commit hash]
- branch: [branch name]

### project.yml 检查
- ReaderForIOSApp sources: [列出]
- 危险 source 发现: [是/否]

### iOS boundary
- 结果: [PASS/FAIL]
- checked_files: [数量]

### 构建结果
- xcodegen: [成功/失败]
- xcodebuild: [成功/失败/BUILD SUCCEEDED]

### 风险提示
- [如有]

### 下一步
- [建议]
```

## 注意事项

1. 如果发现 `../Reader-Core` 或 `Core/Sources` 在 App target sources 中，**必须标记为风险**
2. 如果出现 duplicate class 错误，优先检查 project.yml target sources
3. 真实 WebView URL 测试需要用户单独授权
4. 不得修改 Reader-Core Parser 或 ReaderCoreModels 内部实现