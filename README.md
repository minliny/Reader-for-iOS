# Reader for iOS

Reader 的 iOS SwiftUI 客户端，最低系统版本 iOS 17。App 包标识为 `io.reader.minliny`。
Core 负责书库、正文、目录、位置、规则与事务；iOS Host 负责文件授权、展示、网络与平台资源。
Core Swift wrapper 与 App 编入同一个 `Reader` 模块，底层 C 模块 `ReaderCore` 来自静态 XCFramework。

当前开发源码已扩展到 V2 日用 TXT、V3 多格式本地与阅读工具、V4 在线小说，
新增接线与修复的 `SOURCE_READY` 不代表版本交付或最新 App 验收通过。
能力、原书保护、已知方法结果与平台边界见 [阅读能力与所有权说明](docs/LOCAL_READING.md)。
版本必做范围与完成状态只在工作区唯一待办
[iOS V2–V8 版本要求](../DEVELOPMENT_BACKLOG.md#ios-version-requirements) 维护。
V5 听书、V6 漫画尚不属于本客户端已支持能力；AZW/AZW3/KF8 的真实原书验证按用户要求暂跳过，仍为 OPEN。

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

默认只构建 arm64 iOS Simulator（显式设置 `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`），
不提供 Intel Simulator slice。Core 构建从固定 commit 建立独立本地快照，再调用其中的
`scripts/build-ios-xcframework.sh`；其嵌套动作只有 `cargo rustc` 与
`xcodebuild -create-xcframework`，不传 `--swift-smoke`，不运行业务测试。
Core 产物与实际输入绑定在 `.build/core-build.json`，工程使用 `.build/ReaderCore.xcframework`。
环境显式设置 `IPHONEOS_DEPLOYMENT_TARGET=17.0`；回执记录该输入，并以 Apple 工具核对
归档内对象的最低部署版本。高于 17.0 的旧对象不能靠重拍 SHA 登记为兼容。

App 编译、测试与不可变 App 产物分别位于用户缓存目录，实际路径从同一个入口查询：

```sh
python3 scripts/build-paths.py --kind root
python3 scripts/build-paths.py --kind app-derived
python3 scripts/build-paths.py --kind test-derived
python3 scripts/build-paths.py --kind artifacts
```

默认根目录为 `~/Library/Caches/Reader-iOS/<工作区身份>/`。可用 `READER_IOS_BUILD_ROOT`
指定绝对路径；入口拒绝工作区、Documents、Desktop 及所识别的 FileProvider 位置。
这只选择构建输出位置，源码、下载目录原书与已安装 App 的数据目录不迁移。
旧 `.build/AppDerivedData`、`.build/TestDerivedData`、`.build/app-artifacts` 中的历史产物
不作为新构建的输出目录。

App 使用 `xcodebuild ... build`，每次在查询所得 App DerivedData 下的新 `<run-id>` 编译，
与测试产物分开。模拟器采用本地 ad-hoc 签名，并核对实际模拟器包与 Keychain 访问身份；
该身份核验不代替真实网络登录测试或设备签名验收。
已准备配套 Core 产物时可运行 `./scripts/build.sh --skip-core`，仍核对原产物与固定源码绑定；
`--configuration Release` 切换 App 构建配置。

编译前保存直接输入快照，编译后核对输入没有变化，并拒绝包含 `.xctest` 的 App。
成功后将 App、输入快照与配套 Core 回执复制到查询所得 artifacts 下的 `<run-id>/`，
保存 schema 2 `manifest.json` 并设为只读。`.build/app-build.json` 仍是最新产物回执指针
（完整回执副本），绑定输入指纹、包身份和 App 文件 SHA；交付 App 来自该次不可变目录的 `Reader.app`。
修改构建路径不会把旧产物自动改认成新产物，也不表示新构建已通过。

需要设备或双平台 Core slice 时显式使用 `./scripts/build-core.sh --platform device` 或
`--platform all`，并提前安装对应 Rust targets。真机签名应在 Xcode 选择有效开发团队和
适配 `io.reader.minliny` 的 Apple provisioning；HarmonyOS 证书不用于 Apple 签名。

## 验证范围

构建必要核验仅包含固定 Core 对象和 wrapper 配对、对应编译工具/目标、XCFramework 文件
完整性、App 编译及模拟器包/签名与 Keychain 身份；没有自动前置或附带的业务门禁。`Reader` scheme 的普通 Build 不构建
或运行 `ReaderTests`。测试必须另外指定准确模拟器 UDID 与所需类或方法：

```sh
./scripts/test.sh --destination 'platform=iOS Simulator,id=<UDID>' --only ReaderTextCoordinatesTests
```

测试入口只使用已绑定的 Core 产物，不自动补建 Core；不选择 `--only` 时停止，不运行全量。
原生 UI 测试另加 `--target ReaderUITests` 并选择该 target 的准确类或方法。
测试输出使用 `build-paths.py --kind test-derived` 查询所得目录。入口先执行
`build-for-testing`，核对编译出的模拟器 App 身份，再以 `test-without-building` 只运行所选方法；
该动作会在指定目标安装和运行测试 App。`-collect-test-diagnostics never` 禁用整机诊断采集，
XCTest 常规失败附件、截图与日志仍保留。
工程生成和 App 构建不操作模拟器。构建、所选测试、模拟器安装/交互、真机及用户验收分别记录。

`ReaderNativeJourneyTests/testNativePickerToReadingAndColdReopen` 使用下载目录的真实
`仙子请听我解释.txt`。运行前将原文件按字节复制到所选模拟器的 Reader Documents，
核对原件与副本 SHA-256；测试通过系统文件选择器导入，不在 App 内生成或注入小说。
书籍内容不纳入仓库，输入身份和原生交互结果保存在本次私有交付证据中。

## 模拟器覆盖安装

```sh
./scripts/deploy-simulator.sh --udid <UDID> --launch
```

该入口只接受显式 UDID，要求目标已启动；安装前退出 App 并停止并行数据写入。
它只读取一次 `.build/app-build.json`，核对其中
固定目录的 App、输入快照与 Core 回执后，使用同一份只读 App 调用 `simctl install`
覆盖同一 bundle；后续构建更新最新回执不会改变本次安装来源。
安装前及安装后启动前，比较受保护相对文件的摘要：`Documents`、`Library/Application Support`
递归文件及存在时的 `Library/Preferences/io.reader.minliny.plist`。普通文件逐字节核对 SHA-256；
SQLite 主库使用 Python sqlite3 只读连接的 `iterdump` 语义 SHA，不输出内容，配套 `-wal`/`-shm`
不按字节比较，以允许合法 checkpoint。容器路径允许迁移、新文件允许增加，既有受保护文件
不得丢失或变化；首次安装没有安装前数据。数据核对失败时不启动 App。
不会自动启动其他模拟器，也不执行卸载、擦除、构建或测试。`--launch` 为可选的独立启动动作。
原始安装与启动回执保存在 `.build/deployments/`，记录路径迁移、保护摘要与比较及部署脚本 SHA。
既有失败回执保留；保护摘要通过仍不能替代书籍与进度的交互验证。

固定视觉/交互参考与当前运行依赖分开：参考仍使用 `Resources/Reference/manifest.json`
登记的冻结 Git 对象；当前 Core pin 和 wrapper SHA 以 `scripts/core-dependency.json` 为准。
V2–V4 的新目录/电子书、规则订阅及原操作恢复合同需要配套 Core 升级，不能仅凭 Swift 接线
就让旧 Framework 获得新能力。当前 pin 为 `b6a5bb9294279acda508b1492f1ed3592907d427`，
本次在线入架文档计数修复的模拟器 Framework 已实际构建并核对最低版本；此前 Core141、e978 只读调试的结果保留，具体方法及原生结果见 [能力与证据边界](docs/LOCAL_READING.md#已有结果与尚未闭合的证据)。
最终交付 App 和保数据安装另行绑定，测试宿主不充当交付 App。

更新 Core 时先登记协议、schema、位置迁移和原未决操作的兼容边界，调整固定 commit 与准确
wrapper SHA，再同步 Vendor、重建 Core 和 App。保留原书、已确认位置和原操作 journal；
不要手改 Vendor，也不要把旧 XCFramework 重新登记为新源码产物。
在已知实际构建入口与输入的情况下，手动登记 Core 产物须同时提供
`record-framework --source <实际源码目录> --deployment-target 17.0`；此动作仍执行 Mach-O 核验。
