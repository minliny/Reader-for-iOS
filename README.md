# Reader iOS 重建

首波工程壳含 Core Swift 6 桥、原生文件 Host、共享电子书 WKWebView 适配和测试宿主。iOS 部署目标为 17.0。模拟器开发使用 `io.reader.minliny.rebuild.m1`。

| 目录 | 职责 |
| --- | --- |
| `Sources/ReaderCoreBridge` | 从固定协议生成物消费 DTO，持有 Core 运行时并路由原请求与 ACK |
| `Sources/ReaderHost` | Library47 准入、文件授权与原书留存、导入 journal、System Host 插槽 |
| `Sources/ReaderDesign` | 固定 Reader-UI 的 Swift 色、度量及图标声明 |
| `Sources/ReaderApp` | 启动壳、导入事务协调、阅读会话与 WKWebView 适配 |
| `Resources/reader_ebook_runtime` | 固定 Reader-UI 的三个生产电子书资源 |
| `Tests` | 独立 XCTest 宿主测试与固定 EPUB、存储、标量夹具 |

Swift 模块调用由 App 指向 Host、Bridge 和 Design，由 Host 指向 Bridge，由 Bridge 链接 ReaderCore C 模块。位于 `Scripts/pins.json` 的三仓提交决定输入，`Scripts/input-receipt.json` 记录源和同步文件的 SHA-256。同步仅从 Git 对象读取。

## 构建与验证

```sh
python3 Scripts/sync-inputs.py --check
python3 Scripts/check-architecture.py
Scripts/build-core.sh --swift-smoke
Scripts/build-app.sh
```

`build-core` 从固定 Core commit 创建独立快照和 arm64 模拟器静态 XCFramework，核对嵌入的 Git 身份、Mach-O 平台和最低系统。`build-app` 编译无签名模拟器壳，并核对生产包的资源摘要。

对获准的专用 iOS 模拟器，使用同一 XCTest 候选先写入，再独立进程读回。两个阶段均以 PID 证明冷启边界。数据、原书和测试夹具限定在该测试 App 容器。

```sh
Scripts/test-simulator.sh build "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh write "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh cold "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
```

修改固定输入需执行 `Scripts/sync-inputs.py --write`。生成 Swift 文件原样同步，测试专属夹具按建库与阅读用例归入 XCTest 目标。
