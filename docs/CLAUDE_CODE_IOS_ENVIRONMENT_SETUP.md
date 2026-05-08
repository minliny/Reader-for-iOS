# Claude Code iOS 开发环境配置说明

## 1. 如何从 Reader for iOS 根目录启动 Claude Code

```bash
cd "/Users/minliny/Documents/Reader for iOS"
claude
```

## 2. 如何检查当前目录

启动后首先确认：

```bash
pwd
```

应该输出：`/Users/minliny/Documents/Reader for iOS`

如果不对，说明 Claude Code 没有从正确的目录启动。

## 3. 如何使用自定义命令

启动后可以使用斜杠命令：

```
/ios-dev
```

这将执行 iOS 开发环境检查和构建命令。

## 4. 如何检查命令是否加载

如果命令没有响应，运行：

```
/help
```

检查自定义命令是否已加载。

## 5. 建议允许的命令

在 Claude Code 设置中，建议允许以下命令：

### 安全的只读/构建命令

- `Bash(git status:*)` - 查看 git 状态
- `Bash(git rev-parse:*)` - 查看 HEAD commit
- `Bash(git log:*)` - 查看提交历史
- `Bash(git diff:*)` - 查看文件变更
- `Bash(find:*)` - 查找文件
- `Bash(ls:*)` - 列出目录
- `Bash(cat:*)` - 读取文件
- `Bash(grep:*)` - 搜索内容
- `Bash(swift test:*)` - 运行 Swift 测试
- `Bash(xcodebuild -list:*)` - 列出 Xcode 项目信息
- `Bash(xcodebuild build:*)` - 构建 iOS 项目
- `Bash(xcrun simctl list:*)` - 列出可用模拟器
- `Bash(xcodegen generate:*)` - 生成 Xcode 项目
- `Bash(bash scripts/check_ios_boundary.sh:*)` - iOS 边界检查

### 建议保留询问的高风险命令

以下命令建议每次使用时单独确认：

- `Bash(rm:*)` - 删除文件（危险）
- `Bash(git reset:*)` - 重置 git（危险）
- `Bash(git clean:*)` - 清理 git（危险）
- `Bash(git push:*)` - 推送到远程（危险）
- `Bash(curl:*)` - 网络请求（可能危险）
- `Bash(wget:*)` - 网络请求（可能危险）
- `Bash(open:*)` - 打开文件/应用（可能危险）
- `Bash(xcrun simctl erase:*)` - 清除模拟器数据（危险）
- `Bash(xcrun simctl delete:*)` - 删除模拟器（危险）

## 6. 为什么不要全局放开所有权限

全局放开所有 Bash 命令存在以下风险：

1. **数据丢失风险**：`rm -rf`、`git clean -f` 等命令可能永久删除文件
2. **网络风险**：`curl`、`wget` 可能发送敏感数据到外部
3. **隐私风险**：`open` 可能打开钓鱼网站或恶意应用
4. **项目完整性**：`git push --force` 可能覆盖重要代码

建议：
- 只读命令可以全局允许
- 修改性命令每次单独确认
- 网络命令单独确认并限制
- 危险命令（如 rm、git reset）永远不要全局允许

## 7. 如何处理 Unknown command 问题

如果 `/ios-dev` 命令显示 "Unknown command"，按以下步骤检查：

### Step 1: 确认命令文件存在

```bash
ls -la .claude/commands/
```

应该看到 `ios-dev.md` 文件。

### Step 2: 确认从仓库根目录启动

```bash
pwd
```

应该是 `/Users/minliny/Documents/Reader for iOS`。

### Step 3: 重启 Claude Code

退出当前 Claude Code 会话，重新启动：

```bash
cd "/Users/minliny/Documents/Reader for iOS"
claude
```

### Step 4: 检查 Claude Code 版本

```bash
claude --version
```

确保是最新版本。

## 8. 权限配置示例

在 Claude Code 设置中添加以下权限：

```json
{
  "permissions": {
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
}
```

## 9. 常用工作流程

### 启动项目

```bash
cd "/Users/minliny/Documents/Reader for iOS"
claude
/ios-dev
```

### 构建项目

```bash
xcodebuild build \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 检查边界

```bash
bash scripts/check_ios_boundary.sh
```

## 10. 常见问题

### Q: 为什么构建失败？

A: 检查以下内容：
1. `xcodebuild -list` 是否正确识别项目
2. `project.yml` 是否有语法错误
3. Simulator 是否可用：`xcrun simctl list devices available`

### Q: 出现 duplicate class 错误怎么办？

A: 检查 `project.yml` 中 `targets.ReaderForIOSApp.sources` 是否错误包含了：
- `Core` / `Core/Sources`
- `../Reader-Core`
- `../Reader-Core/Core/Sources`

这些不应该出现在 App target 的 sources 中。

### Q: 如何确认 Reader-Core 通过 package 引入？

A: 检查 `project.yml` 的 `packages` 和 `targets` 部分：

```yaml
packages:
  ReaderCore:
    path: ../Reader-Core/Core

targets:
  ReaderForIOSApp:
    dependencies:
      - package: ReaderCore
        product: ReaderCoreModels
```