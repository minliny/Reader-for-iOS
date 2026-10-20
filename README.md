# Reader for iOS

Reader 的 iOS SwiftUI 客户端，最低系统版本 iOS 17。App 包标识为 `io.reader.minliny`。
本地 TXT 的导入、目录、正文与位置由 Rust Reader Core 提供；iOS Host 负责文件授权、
持久化目录、界面和用户意图。Core Swift wrapper 与 App 编入同一个 `Reader` 模块，
底层 C 模块 `ReaderCore` 来自静态 XCFramework。
首版本地阅读能力与恢复边界见 [本地阅读说明](docs/LOCAL_READING.md)。

## 工程与依赖

- `Sources/ReaderApp`：SwiftUI 页面与展示组件。
- `Sources/ReaderRuntime`：iOS 文件与 Core 业务适配。
- `Tests/ReaderRuntimeTests`：以 `@testable import Reader` 使用 App 模块的单元测试。
- `Tests/ReaderUITests`：通过原生 UI 测试操作 App 的交互验证。
- `Resources`：随 App 打包的字体、图标与资源来源说明。
- `project.yml`：XcodeGen 工程定义；生成的 `Reader.xcodeproj` 一并保存。
- `scripts/core-dependency.json`：Core commit 与 Swift wrapper 的固定来源和 SHA-256。
- `Vendor/ReaderCoreClient`：从固定 Git 对象原样同步的公共 wrapper，不在此修改业务。

需要完整 Xcode、XcodeGen、Python 3，以及 Core `rust-toolchain.toml` 指定的 Rust 工具链。
默认从相邻的 `../Reader-Core` 读取 Git 对象，也可设置 `READER_CORE_ROOT` 指向已有 checkout。
这不会读取或修改该 checkout 的未提交源码。

```sh
./scripts/generate-project.sh
open Reader.xcodeproj
```

工程生成只同步固定 wrapper 并运行 XcodeGen，不编译、运行测试或操作模拟器。
添加或移动 Swift/资源/测试文件后重新生成工程。

## 构建

```sh
./scripts/build.sh
```

默认只构建 arm64 iOS Simulator（显式设置 `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`），不提供 Intel
Simulator slice。先在本仓 `.build/core-source/<commit>` 建立固定 Core
commit 的独立本地快照，再调用该快照的 `scripts/build-ios-xcframework.sh`；其嵌套动作只有
`cargo rustc` 与 `xcodebuild -create-xcframework`，不传 `--swift-smoke`，不运行业务测试。
编译缓存位于 `.build/core-target`，XCFramework 位于 `.build/ReaderCore.xcframework`。
每次 Core 打包后记录 `.build/core-build.json`，绑定实际输入身份、wrapper SHA 和所有
XCFramework 文件 SHA。构建环境显式设置 `IPHONEOS_DEPLOYMENT_TARGET=17.0`；回执记录该输入，
并通过 `xcrun otool -l` 检查归档内 Mach-O 对象的最低部署版本。高于 17.0 的旧对象不能只靠
重拍 SHA 登记为兼容。快照路径变化不会使已绑定、字节未变的产物失效。

App 构建使用 `xcodebuild ... build`，每次在全新的 `.build/AppDerivedData/<run-id>` 编译，
与测试输出分开。默认关闭模拟器代码签名。
已准备配套 Core 产物时可运行 `./scripts/build.sh --skip-core`；该参数仍校验产物与源码绑定。
`--configuration Release` 切换 App 构建配置。
App 编译前保存直接输入快照，编译后核对输入没有变化，并拒绝包含 `.xctest` 的 App。
成功后将 App、输入快照与配套 Core 回执复制到 `.build/app-artifacts/<run-id>/`，保存
`manifest.json` 并设为只读。`.build/app-build.json` 原子更新为该次完整回执的副本，绑定
输入指纹、包身份与 App 文件 SHA；交付 App 位于该次目录的 `Reader.app`。

需要设备或双平台 Core slice 时显式使用 `./scripts/build-core.sh --platform device` 或
`--platform all`，并提前安装对应 Rust targets。真机签名应在 Xcode 选择有效开发团队和
适配 `io.reader.minliny` 的 Apple provisioning；HarmonyOS 证书不用于 Apple 签名。

## 验证范围

构建必要核验仅包含固定 Core 对象和 wrapper 配对、对应编译工具/目标、XCFramework 文件
完整性及 App 编译；没有自动前置或附带的业务门禁。`Reader` scheme 的普通 Build 不构建
或运行 `ReaderTests`。测试必须另外指定准确模拟器 UDID 与所需类或方法：

```sh
./scripts/test.sh --destination 'platform=iOS Simulator,id=<UDID>' --only ReaderTextCoordinatesTests
```

测试入口只使用已绑定的 Core 产物，不自动补建 Core；不选择 `--only` 时停止，不运行全量。
原生 UI 测试另加 `--target ReaderUITests` 并选择该 target 的准确类或方法。
测试输出使用 `.build/TestDerivedData`；`xcodebuild test` 会在指定目标安装并运行测试所需
App。失败后不自动收集整机诊断，XCTest 常规失败附件、截图与日志仍保留。
工程生成和 App 构建不操作模拟器。构建、所选测试、模拟器安装/交互、真机及用户验收分别记录。

`ReaderNativeJourneyTests/testNativePickerToReadingAndColdReopen` 使用下载目录的真实
`仙子请听我解释.txt`。运行前将原文件按字节复制到所选模拟器的 Reader Documents，
核对原件与副本 SHA-256；测试通过系统文件选择器导入，不在 App 内生成或注入小说。
书籍内容不纳入仓库，输入身份和原生交互结果保存在本次私有交付证据中。

## 模拟器覆盖安装

```sh
./scripts/deploy-simulator.sh --udid <UDID> --launch
```

该入口只接受显式 UDID，要求目标已启动。它只读取一次 `.build/app-build.json`，核对其中
固定目录的 App、输入快照与 Core 回执后，使用同一份只读 App 调用 `simctl install`
覆盖同一 bundle，并核对安装前后数据容器路径；后续构建更新最新回执不会改变本次安装来源。
不会自动启动其他模拟器，也不执行卸载、擦除、构建或测试。`--launch` 为可选的独立启动动作。
原始安装与启动回执保存在 `.build/deployments/`；容器路径保留只证明安装动作保数据，
不能替代书籍与进度的交互验证。

更新 Core 时先调整 `scripts/core-dependency.json` 的 commit 和准确文件 SHA，再同步 wrapper、
重建 Core 和 App。不要手改 Vendor 副本，也不要把旧 XCFramework 重新登记为新源码的产物。
在已知实际构建入口与输入的情况下，手动登记 Core 产物须同时提供
`record-framework --source <实际源码目录> --deployment-target 17.0`；此动作仍执行 Mach-O 核验。
