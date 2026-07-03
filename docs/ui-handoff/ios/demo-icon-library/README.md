# Reader 素材库（Reader Asset Library）

本目录把当前 UI 设计图、封面图片和图标 token 统一成一个可浏览、可验证的前端输入件素材库。

## 文件（Files）

- `preview.html`：素材库可视化预览页。
- `fixture.json`：素材库数据源，供真实前端或转换脚本读取。
- `fixture.js`：file 协议下可直接运行的 fixture 镜像。
- `icons.js`：统一图标注册表，补齐当前页面已引用但未集中登记的图标 token。
- `render.js`：`window.ReaderAssetLibrary` 渲染器。
- `asset-library.css`：素材库页面样式。

## 范围（Scope）

- UI 设计图（UI Design Screens）：30 张 `UI设计图.png`。
- 书籍封面素材（Book Cover Assets）：6 张书架封面图片。
- 图标素材（Icon Assets）：当前 fixture 中扫描出的 55 个图标 token，加上 Shell、阅读控制、状态栏和 Compose 语义追溯补充图标，共 90 个本地 token。
- 验证截图（Validation Screenshots）：60 张 `design-draft-*.png` 作为验证素材集合登记，不在预览页逐张加载。

## 使用规则（Usage Rules）

- 新页面转换前先查 `icons.js`，已有图标不得另起同义名称。
- 新增图标必须先进入素材库，再进入页面 renderer。
- UI 设计图作为源图引用；验证截图作为验收证据引用；二者不得混用。
- `preview.html` 是正式前端输入件，必须进入 manifest。
- 素材库变更后必须运行 `FrontendInputAssetLibraryInventoryTest`，确认 fixture、图标注册表、实际文件、manifest 和验证报告仍一致。
