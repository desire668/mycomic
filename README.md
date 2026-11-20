# MyComic — 原生 iOS 漫画客户端

MyComic 是一个使用 **Swift + SwiftUI** 编写的第三方原生 iOS 漫画客户端，数据来自 `https://mycomic.com/cn`。

本项目**不是网页壳**：首页、分类、排行榜、搜索、漫画详情、章节列表、书架、个人中心和漫画阅读器全部由 SwiftUI 原生实现，网络数据由 Swift `URLSession` 获取，HTML 由项目内置的解析器提取。WKWebView 仅用于用户主动发起的 Cloudflare 交互验证。

> 本项目与 mycomic.com 官方无关，不提供、不托管任何漫画内容。请遵守当地法律与网站条款，支持正版。

---

## 1. 功能列表

### 已实现并通过代码/测试验证

| 模块 | 功能 |
|---|---|
| 首页 | 最近更新、最新上架、人气推荐；下拉刷新；分页；加载/空数据/错误状态；继续阅读卡片 |
| 分类 | 按类型 / 地区 / 受众 / 年份 / 连载状态组合筛选；排序；分页；清除筛选 |
| 排行榜 | 周榜 / 月榜 / 总榜（站点实际提供的三个榜单） |
| 搜索 | 关键词搜索；输入防抖；搜索历史（本地）；清空历史；排序；分页 |
| 详情 | 封面、标题、作者、简介、地区、标签、连载状态、章节总数、章节正序/倒序 |
| 阅读器 | 纵向连续阅读、单页左右翻页、双击/捏合缩放、上一章/下一章、目录跳转、进度保存与恢复、图片预加载、内存 + 磁盘缓存、屏幕常亮、横竖屏、iPhone/iPad 适配 |
| 书架 | 本地收藏、移除、最近阅读、继续阅读（书架保存在本机，**不是**服务器收藏） |
| 我的 | 站点登录状态检测、实验性原生登录、Cloudflare 验证状态、Cookie 管理 |
| 设置 | 阅读模式、自动加载下一章、屏幕常亮、保存历史、清理图片缓存、清理网络缓存、清除 Cookie（二次确认）、Cloudflare 验证入口、网络状态、版本信息 |
| 网络 | 统一 `APIClient`、超时、重试、Cookie、Cloudflare 检测、错误映射、请求取消 |
| 图片 | JPEG/PNG/WebP 自动识别、Referer、下采样解码、NSCache 内存缓存、磁盘 LRU 裁剪、请求去重、预加载 |

### 已知限制（请务必阅读）

- **站点没有公开 JSON API**。所有列表、搜索、详情、章节和图片地址均来自服务端渲染的 HTML，通过 `MyComicParser` 解析。网站改版会导致解析失败。
- **Cloudflare 无法、也不应被绕过**。应用只提供交互式验证页面，并尝试同步 Cookie。`cf_clearance` 与 IP、User-Agent、有效期绑定，同步后仍可能失败；失败时应用会明确提示。
- **书架与阅读历史仅保存在本机**（JSON 文件 + `Application Support`），站点没有可用的收藏 API。
- **登录为实验性功能**：表单字段依据网站实际页面实现，但登录后的完整用户中心功能尚未验证，失败时不会伪造成功。
- 章节图片 CDN 必须携带 `Referer: https://mycomic.com/`，否则返回 403。应用已按此实现，但 CDN 策略随时可能调整。
- 未签名 IPA 不能直接安装，需要自签名工具（见下文）。

---

## 2. 技术架构

```
SwiftUI View
    ↓ 只负责展示 / 用户交互
ViewModel (@MainActor, ObservableObject)
    ↓
ComicRepository（缓存 / 分页 / 数据转换 / 错误传递）
    ↓
MyComicAPI（接口定义） → APIClient（URLSession / Cookie / 错误映射）
    ↓
MyComicParser + HTMLDocument（无第三方依赖的 HTML 解析）
    ↓
ImagePipeline（内存 + 磁盘缓存、下采样、预加载、去重）
```

目录结构：

```
MyComic/
├── App/                 MyComicApp.swift（入口、环境对象、Tab）
├── Models/              Comic / ComicDetail / Chapter / RankEntry ...
├── Services/
│   ├── APIClient.swift  URLSession、请求头、Cloudflare 检测、UA
│   ├── MyComicAPI.swift 首页 / 列表 / 搜索 / 排行 / 详情 / 章节
│   ├── MyComicParser.swift 基于 HTML 的结构化解析
│   ├── HTMLDocument.swift 轻量 HTML 解析器（无第三方依赖）
│   ├── CookieManager.swift Cookie 同步 / 清理 / WKWebView 配置
│   ├── ImagePipeline.swift 图片下载、缓存、下采样
│   ├── LibraryStore.swift 本地书架与阅读历史
│   ├── SettingsStore.swift 阅读设置
│   └── NetworkMonitor.swift NWPathMonitor
├── Repositories/        ComicRepository
├── ViewModels/          Home / List / Search / Detail / Reader / Rank / Profile / Session
├── Views/               Home / Category / Search / Detail / Reader / Shelf / Profile / Settings
├── Components/          ComicCard / ComicGrid / RemoteImageView / ErrorStateView ...
└── Resources/           Info.plist / Assets.xcassets
Tests/MyComicTests/      解析、网络、Cloudflare、缓存相关单元测试
docs/API_ANALYSIS.md     接口调查与实测记录
.github/workflows/build-ipa.yml
```

最低系统版本：**iOS 15.0**，支持 iPhone 与 iPad。

---

## 3. 项目截图

本仓库不放置伪造截图。运行应用后可自行截图；推荐截取：首页、分类筛选、搜索结果、漫画详情、纵向阅读器、单页阅读器、书架、设置页。

在 GitHub Actions 成功构建后，可从 Artifacts 下载 IPA 安装到设备后截图补充。

---

## 4. API 数据来源说明

站点为 Laravel + Livewire 服务端渲染页面，**没有公开 JSON API**。实测确认的数据来源：

| 数据 | 实际请求 |
|---|---|
| 列表 / 筛选 / 搜索 | `GET https://mycomic.com/cn/comics`，参数 `q`、`sort`、`filter[tag]`、`filter[country]`、`filter[audience]`、`filter[year]`、`filter[end]`、`page` |
| 最新上架 | 默认排序（等价于按 id 倒序） |
| 最近更新 | `?sort=-update` |
| 最高人气 | `?sort=-views` |
| 排行榜 | `GET /cn/rank`，`?sort=-week` / `-month` / `-views` |
| 漫画详情 | `GET /cn/comics/{id}` |
| 章节阅读 | `GET /cn/chapters/{id}` |
| 图片 CDN | `https://biccam.com/...`，必须携带 `Referer: https://mycomic.com/` |

分页为 `page=N`，每页 30 部；排行榜为单页 50 条、无分页。

完整请求示例、字段说明、响应样本和未验证项见 **[docs/API_ANALYSIS.md](docs/API_ANALYSIS.md)**。

参考项目：[venera-configs/mycomic.js](https://github.com/venera-app/venera-configs/blob/main/mycomic.js)（仅作功能与数据结构参考，Swift 代码为独立实现）。

---

## 5. Cloudflare 交互验证说明

1. 正常业务请求全部使用 `URLSession`；当响应出现 403/503/429 且带有 Cloudflare 特征（`Just a moment...`、`challenge-platform`、`cf-mitigated` 等）时，映射为 `AppError.cloudflareRequired`。
2. 界面显示明确提示与「进行 Cloudflare 验证」按钮。
3. 用户主动打开独立 `WKWebView` 页面，手动完成 Cloudflare 的交互验证。
4. 点击「完成验证并同步 Cookie」后，应用把 `mycomic.com` / `biccam.com` 的 Cookie 写入 `HTTPCookieStorage`，并记录 WebView 的 User-Agent 供 `URLSession` 使用。
5. 应用**不会**破解挑战、伪造验证结果、伪造浏览器指纹，也不使用任何第三方 CF 绕过服务。
6. 若 Cookie 无法用于原生请求，应用会如实报错，不会声称验证成功。

> 说明：`cf_clearance` 可能与出口 IP、UA、浏览器环境以及有效期绑定。即使同步成功，也可能在更换网络后失效，需要重新验证。

---

## 6. Xcode 本地编译

环境要求：Xcode 15+，macOS，iOS 15+ 的真机或模拟器。

```bash
git clone https://github.com/desire668/mycomic.git
cd mycomic
open MyComic.xcodeproj
```

- Scheme：`MyComic`
- 运行目标：任意 iPhone / iPad（iOS 15+）
- 无需 CocoaPods / Swift Package 依赖，项目可直接编译。

命令行构建：

```bash
xcodebuild \
  -project MyComic.xcodeproj \
  -scheme MyComic \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO clean build
```

运行单元测试：

```bash
xcodebuild test \
  -project MyComic.xcodeproj \
  -scheme MyComic \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

---

## 7. GitHub Actions

工作流：[.github/workflows/build-ipa.yml](.github/workflows/build-ipa.yml)

- 触发：push 到 `main`、手动 `workflow_dispatch`、发布 GitHub Release。
- `test` Job：在 iOS 模拟器上运行 `MyComicTests`（解析、网络错误映射、Cloudflare 检测、图片下采样）。
- `build` Job：`macos-latest` + Release + `generic/platform=iOS` + `CODE_SIGNING_ALLOWED=NO`，无需证书和 Apple Developer 账号。
- 校验：`.app` 是否存在、`Info.plist`、Bundle Identifier（`com.mycomic.app`）、最低系统（15.0）、Payload 结构、zip 完整性。
- 产物：`MyComic-unsigned.ipa`（Artifacts，保留 30 天）；main 分支构建成功后自动更新滚动预发布 Release，Release 触发时附加到对应 Release 资产。

### IPA 下载

1. 直接下载（每次 main 构建成功后自动更新）：
   [MyComic-unsigned.ipa](https://github.com/desire668/mycomic/releases/download/unsigned-latest/MyComic-unsigned.ipa)
2. 或打开仓库 **Actions** → 最新成功的 **Build Unsigned IPA**，在页面底部 **Artifacts** 下载 `MyComic-unsigned-ipa.zip`，解压得到 `MyComic-unsigned.ipa`。
3. 或在 **Releases** 页面下载同名 `.ipa` 文件（由 Release 触发构建时生成）。

---

## 8. 安装教程（需自签名）

未签名 IPA 不能直接安装，以下工具均需要你自己的 Apple ID（免费账号也可，签名有效期 7 天）。

### AltStore

1. 电脑安装 [AltServer](https://altstore.io/)，iPhone 安装 AltStore（通过 AltServer 安装）。
2. 在 iPhone「设置 → 通用 → VPN 与设备管理」中信任开发者证书。
3. 把 IPA 传到 iPhone（AirDrop / 文件 App），在 AltStore 的 **My Apps → +** 中选择该 IPA。
4. 输入 Apple ID 完成签名安装。免费账号需每 7 天刷新一次。

### SideStore

1. 按 [SideStore 文档](https://sidestore.io/) 使用 AltServer / Jitterbug 完成首次安装。
2. 在 SideStore 中 **+** 选择 IPA，登录 Apple ID 签名安装。
3. 支持同一 Wi-Fi 下无线刷新（需配对文件）。

### Sideloadly

1. 电脑安装 [Sideloadly](https://sideloadly.io/) 与 iTunes（Windows）。
2. 连接 iPhone，拖入 `MyComic-unsigned.ipa`，填写 Apple ID。
3. 点击 Start，输入 Apple ID 密码/专用密码，等待完成。
4. 首次启动前在「设置 → 通用 → VPN 与设备管理」信任证书。

### 爱思助手

1. 电脑安装爱思助手并连接 iPhone。
2. 打开「工具箱 → IPA 签名」，添加 `MyComic-unsigned.ipa`，使用自己的 Apple ID 签名。
3. 签名完成后通过「应用游戏 → 导入安装」安装到设备。
4. 若提示未信任，前往「设置 → 通用 → VPN 与设备管理」信任。

> 以上工具均可能要求关闭「查找我的 iPhone」或使用专用密码；请以工具最新文档为准。请勿使用来历不明的企业证书。

---

## 9. 常见问题

**Q：首页一直提示 Cloudflare 验证？**
A：从设置或错误页进入验证页面，完成网站提供的交互验证并同步 Cookie。若仍失败，通常是出口 IP 或 Cookie 有效期问题，请更换网络后重试。应用不会绕过验证。

**Q：图片显示 403？**
A：图片 CDN 要求 `Referer`。应用已自动携带 `https://mycomic.com/`；若 CDN 规则变化，需要更新代码。

**Q：书架能同步到网站账号吗？**
A：不能。站点没有公开收藏 API，书架与历史仅保存在本机。卸载应用会丢失。

**Q：搜索/详情空白？**
A：可能是网站改版导致 HTML 结构变化，请在 Issues 中附上页面地址与截图。

**Q：登录为什么标记为“实验性”？**
A：登录表单字段已在真实页面确认，但登录后的用户中心接口未完整验证；应用不会伪造登录成功。

**Q：iOS 15 能安装吗？**
A：可以，最低版本为 iOS 15.0。

**Q：IPA 安装失败？**
A：确认已使用自己的证书签名；免费 Apple ID 需要每 7 天重签；Bundle ID 冲突时可在签名工具中修改。

---

## 10. 免责声明

- 本项目为第三方开源客户端，与 mycomic.com 官方无任何关联。
- 所有漫画内容、图片、商标及版权归原作者与 mycomic.com 所有。
- 本项目不存储、不托管、不分发漫画内容，仅通过公开网页请求读取数据。
- 使用本项目产生的任何后果由使用者自行承担，请遵守当地法律法规及网站服务条款。
- 请勿将本项目用于商业用途或大规模抓取。
