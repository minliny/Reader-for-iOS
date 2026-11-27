# Reader iOS 重建

M1 本地阅读包含书架、文件导入、详情与目录、统一阅读器、书签和设置。纯文本在 CoreText 表面分页或分块滚动，Core 准入的 EPUB/MOBI 在共用 WKWebView 表面排版。iOS 部署目标为 17.0。模拟器开发使用 `io.reader.minliny.rebuild.m1`。

| 目录 | 职责 |
| --- | --- |
| `Sources/ReaderCoreBridge` | 从固定协议生成物消费 DTO，持有 Core 运行时并路由原请求与 ACK |
| `Sources/ReaderHost` | Library47 准入、文件授权与原书留存、导入 journal、系统能力及网络／WebKit 能力 |
| `Sources/ReaderDesign` | 业务语义色、五类消息投影、固定度量、字体与图标 |
| `Sources/ReaderApp` | 书架、详情、阅读会话及原生表面、设置，以及搜索、书源、在线阅读和下载协调器 |
| `Resources/reader_ebook_runtime` | 固定 Reader-UI 的三个生产电子书资源 |
| `Tests` | 独立 XCTest 宿主、TXT/EPUB/MOBI 与存储夹具、黄金快照 |

Swift 模块调用由 App 指向 Host、Bridge 和 Design，由 Host 指向 Bridge，由 Bridge 链接 ReaderCore C 模块。位于 `Scripts/pins.json` 的三仓提交决定输入，`Scripts/input-receipt.json` 记录源和同步文件的 SHA-256。同步仅从 Git 对象读取。

## 构建与验证

```sh
python3 Scripts/sync-inputs.py --check
python3 Scripts/check-architecture.py
Scripts/build-core.sh --swift-smoke
Scripts/build-app.sh
```

`build-core` 从固定 Core commit 创建独立快照和 arm64 模拟器静态 XCFramework，核对嵌入的 Git 身份、Mach-O 平台和最低系统。`build-app` 编译无签名模拟器产品包，并核对生产包的资源摘要。

对获准的专用 iOS 模拟器，使用同一 XCTest 候选先写入，再独立进程读回。两个阶段均以 PID 证明冷启边界。数据、原书和测试夹具限定在该测试 App 容器。

```sh
Scripts/test-simulator.sh build "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh write "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh cold "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
```

修改固定输入需执行 `Scripts/sync-inputs.py --write`。生成 Swift 文件原样同步，测试专属夹具按建库与阅读用例归入 XCTest 目标。


第 2 波产品测试使用同一测试包执行以下两阶段。写入阶段将三份固定原书交给生产文件选择器委托和真实 Core，挂载产品书架、详情、目录和阅读表面。冷启阶段在不同 PID 中读回同一测试库的原书、书签、进度和实测可见标量。测试系统文件授权入口使用测试目标内的已授权文件 URL。

```sh
Scripts/test-simulator.sh wave2write "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh wave2cold "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
```

黄金视图使用固定 iOS 26.5 视口和字体离线生成。逐张状态、产品参考、输入身份和像素 SHA-256 登记于 `Tests/Goldens/Baselines/manifest.json`。正式产品包核对同时检验原生字体与图标，并检查测试原书和快照未混入。

M2 协调层测试使用仅接受本机回环连接的独立夹具。先在宿主运行
`python3 -u Tests/Loopback/serve.py`，等待 `M2_FIXTURE_READY`。再使用同一测试包依次执行：

```sh
Scripts/test-simulator.sh m2host "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh m2edit "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh m2write "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
Scripts/test-simulator.sh m2cold "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"
```

`m2cold` 使用独立 XCTest 进程读取上一步写入的库和原操作身份。夹具服务进程在三段测试期间保持运行，服务源码和夹具数据均由测试入口持有。

M2 页面回归使用独立的 `ReaderAppUITests` 目标，通过实际页面输入回环网址并驱动生产操作。沿用已启动的回环夹具，执行 `Scripts/test-simulator.sh m2ui "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"`。其中 `m2ui-source` 与 `m2ui-online` 可分别复验书源和在线阅读旅程。

使用 `Scripts/test-goldens.sh verify "$SIMULATOR_UDID" "$DERIVED_DATA" "$EVIDENCE_DIR"` 比对两阶段基准。重录 M2 时用 `record-m2` 输出候选，视觉复核后以 `Scripts/golden-baselines.py accept-m2` 更新九张 M2 基准及清单，再重新构建测试包和比对全部基准。总览使用 `Scripts/golden-baselines.py contact-sheet` 输出到证据目录。

## M3 Host and coordinator lane

The active Core and UI inputs are in `Scripts/pins.json`. The M1/M2 golden
manifest retains its capture pins. The same 27 PNG and pixel digests are
rechecked on the active application. The M3 fixtures live in the XCTest
or loopback targets. Speech uses the existing reading owner; presenting or
dismissing controls carries no playback operation.

Manga uses the Apple ImageIO codec and Core Graphics, available in the
SDK and offline. One native renderer verifies the pinned Core image
inspection against ImageIO's dimensions and orientation, downsamples to
at most 16,384 on the long edge and 4 MP before rounding, and draws bounded
strips up to 1,024 pixels high from the resulting frame. The 24 MP shared
reservation accounts for the original frame, the thumbnail and the copied
visible tiles during the decode. The retained reservation follows each
result's lifetime. The source frame ceiling is 20 MP for scanline formats
and 8 MP for full-frame or interlaced input. Very tall narrow images can
therefore render while oversized frames produce an explicit unavailable
state. Encoded assets use a 64 MiB per-Host bounded scratch cache, retain
the two recent pages per reader owner, and are discarded on retirement.
A parent lock and per-process directory lease allow cold startup to reclaim
interrupted scratch directories while other live owners keep their files.
The Core C ABI transfer remains scoped to its request and operation, with
a 1 MiB maximum chunk and 128 MiB declaration ceiling. A visible strip
carries the original page identity and never increments the logical
ordinal. Core-authored bitmap strip plans use the same image budget
and ImageIO JPEG encoder. Core still owns their original and prepared byte
receipts. The pinned Core accepts a foreground manga prefetch and exposes
queue admission and materialization grants. The coordinator reads actual
chapter state from Core. A queue receipt does not indicate the images
have been downloaded for offline use.

Native speech uses AVSpeechSynthesizer range callbacks, Core Unicode
scalar slicing and version-qualified highlights. HttpTTS uses the typed
Core request and URLSession, then AVAudioPlayer for WAV or MP3. Raw
signed-16-bit PCM is wrapped by AVAudioFile. AVAudioSession handles
focus and interruptions. MPNowPlayingInfoCenter and the remote command
center remain owned by the currently active reading session. Speech
metadata and playback retire with that owner. The existing application
UI remains M1/M2.

To exercise the exact candidate on an isolated iOS 26.5 simulator, start
`python3 -B Tests/Loopback/serve.py` and build the explicitly selected
simulator with `Scripts/test-simulator.sh build`. Run the sibling
`m3write`, `m3cold` and `m3speech` modes with one prepared DerivedData
directory. The cold phase proves a distinct PID against the original
runtime checkpoint. Use `Scripts/test-goldens.sh verify` for the immutable
M1/M2 pixels. Both scripts require the simulator identifier and an
evidence directory. HttpTTS's Core validator requires HTTPS. For the WAV
test, run a second fixture on 18766 with `--tls-cert` and `--tls-key`, and
trust its ephemeral CA only in the dedicated simulator. The listener and
CA stay local, and production uses normal URLSession trust evaluation.
