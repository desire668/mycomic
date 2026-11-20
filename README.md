# MyComic for iOS

MyComic 是一个使用 **Swift + SwiftUI + WKWebView** 开发的 iPhone / iPad 客户端，用于浏览 **https://mycomic.com/cn**。应用完整保留网站自身的页面、账号会话、搜索、分类、收藏与漫画阅读功能，并由 **GitHub Actions** 自动构建未签名 IPA，供用户使用 AltStore、Sideloadly、SideStore、爱思助手等工具自行签名安装。

- 仓库：https://github.com/desire668/mycomic
- Actions 工作流：https://github.com/desire668/mycomic/actions/workflows/build-ipa.yml
- 最新构建产物：Actions 页面中最新一次 `Build Unsigned IPA` 运行 → Artifacts → `MyComic-unsigned-ipa`
- 正式版本：Releases 页面中的 `MyComic-unsigned.ipa`

> 本项目只生成**未签名 IPA**，不包含、也不需要 Apple 开发者证书、企业证书、Apple ID 或任何私钥。

---

## 功能列表

### 启动与界面
- 原生 SwiftUI 启动页（Logo + 名称 + 渐变背景），首页首屏加载完成或 3 秒超时后自动淡出，避免白屏
- 原生底部导航栏：**首页 / 分类 / 搜索 / 书架 / 我的**，每一项都对应网站真实存在的页面
- 原生顶部导航栏：后退、前进、页面标题、刷新/停止、全屏阅读
- 支持 iPhone 与 iPad、横竖屏、状态栏与安全区域适配
- 深色/浅色模式自动适配（跟随系统）

### 网页能力
- WKWebView 加载 `https://mycomic.com/cn`，开启 JavaScript
- 持久化 Cookie 与本地会话（`WKWebsiteDataStore.default()`），关闭再打开仍保持网站登录状态
- 网页内部跳转、`target="_blank"` 新窗口链接均在应用内正常打开
- 站外链接、`tel:`、`mailto:` 使用系统浏览器 / 系统应用打开
- 下拉刷新（`UIRefreshControl`）
- 顶部细进度条（`estimatedProgress`）
- 网络异常、超时、服务器错误、证书错误均有原生错误页与「重新加载」
- 断网时顶部显示离线提示条
- 网页进程被系统回收后自动恢复
- 支持 JS `alert / confirm / prompt` 弹窗

### 浏览与阅读
- 分类页直接使用网站 `/cn/comics`，支持站点自带排序、受众、地区、连载状态筛选与分页
- 搜索使用网站自身的 `GET /cn/comics?q=关键词`，结果与网站完全一致；支持本地「最近搜索」
- 书架（`/cn/bookmarks`）、观看记录（`/cn/records`）、排行榜（`/cn/rank`）、最新上架均使用网站真实页面
- 漫画章节页（`/cn/chapters/...`）可一键进入**全屏阅读**（隐藏状态栏、顶栏与底栏），保留网站原有阅读交互与横屏阅读

### 设置（原生）
- 清除网页缓存
- 清除 Cookie 与登录状态（删除前二次确认，会退出网站账号）
- 实时网络状态与连接类型检测
- 查看应用版本、网站地址、关于应用与合规说明

### 明确不做的事
- 不绕过网站登录验证、付费机制、访问控制或 DRM
- 不抓取、不缓存、不转载漫画内容；所有内容直接来自官方网站
- 不集成任何广告、统计或付费第三方 SDK

---

## 技术栈

| 项目 | 说明 |
| --- | --- |
| 语言 | Swift 5 |
| UI | SwiftUI（少量 UIKit 桥接：WKWebView、UIRefreshControl、UIAlertController、NWPathMonitor） |
| 最低系统 | iOS 15.0 |
| 设备 | iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`） |
| 工程 | `MyComic.xcodeproj`，Xcode 15+ 可直接打开 |
| CI | GitHub Actions，`macos-14` Runner + Xcode 15.x |

---

## 目录结构

```
MyComic.xcodeproj/                 # Xcode 工程（含共享 Scheme）
MyComic/
├── App/
│   └── MyComicApp.swift           # @main 入口
├── Models/
│   └── WebTab.swift               # 五个 Tab 与网站真实路由
├── Views/
│   ├── ContentView.swift          # 根容器、Tab 切换、启动页控制
│   ├── WebScreen.swift            # 单个网页 Tab（顶栏 + 进度条 + 内容）
│   ├── WebView.swift              # UIViewRepresentable 桥接
│   ├── SearchView.swift           # 原生搜索入口 + 最近搜索
│   ├── ProfileView.swift          # 我的（观看记录 / 排行 / 设置…）
│   ├── SettingsView.swift         # 设置与关于
│   ├── LaunchView.swift           # 原生启动页
│   └── WebPageSheet.swift         # 次级页面模态浏览器
├── Components/
│   ├── HeaderBar.swift            # 原生导航栏
│   ├── BottomTabBar.swift         # 原生底部导航栏
│   ├── ProgressBar.swift          # 加载进度条
│   ├── LoadingView.swift          # 首屏加载提示
│   ├── ErrorStateView.swift       # 原生错误页
│   └── OfflineBanner.swift        # 离线提示
├── Services/
│   ├── WebViewModel.swift         # WKWebView 生命周期与导航状态
│   ├── BrowserSession.swift       # 共享配置、Cookie/缓存管理
│   ├── NetworkMonitor.swift       # NWPathMonitor 网络检测
│   └── AppInfo.swift              # 版本信息
└── Resources/
    ├── Info.plist
    └── Assets.xcassets            # AppIcon、启动图、强调色
.github/workflows/build-ipa.yml    # 未签名 IPA 自动构建
```

架构要点：
- 每个网页 Tab **只创建一个 `WKWebView`**，由 `WebViewModel` 持有，切换 Tab 不会重新创建或重新加载
- 所有 Tab 共享同一个 `WKProcessPool` 与 `WKWebsiteDataStore`，登录态一致、内存占用更低
- 首次进入某个 Tab 时才加载首页（`startIfNeeded()`），避免启动时并发请求

---

## 本地运行

1. 安装 Xcode 15 或更新版本（macOS）。
2. 打开 `MyComic.xcodeproj`。
3. 选择 `MyComic` Scheme 与任意 iPhone / iPad 模拟器或真机。
4. 真机运行时，在 *Signing & Capabilities* 中选择你自己的 Team（仅本机调试需要，CI 构建不需要签名）。

命令行构建（未签名）：

```bash
xcodebuild \
  -project MyComic.xcodeproj \
  -scheme MyComic \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
  clean build
```

---

## GitHub Actions 自动构建

工作流文件：[`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml)

触发方式：

| 触发 | 说明 |
| --- | --- |
| `push` 到 `main` | 自动编译并上传 Artifact |
| Actions 页面 → Run workflow | 手动编译 |
| 创建/发布 Release | 构建并自动把 IPA 附加到该 Release |

构建流程：

1. `macos-14` Runner 上使用 Xcode 15.x
2. `xcodebuild -list` 解析工程与 Scheme
3. 以 `generic/platform=iOS`、`Release`、`arm64` 编译
4. 通过 `CODE_SIGNING_ALLOWED=NO`、`CODE_SIGN_IDENTITY=""` 关闭签名
5. 校验 `.app` 产物
6. 组装 `Payload/MyComic.app` 并压缩为 `MyComic-unsigned.ipa`
7. 校验 IPA 结构（必须包含 `Payload/MyComic.app/MyComic`）
8. 上传 Artifact：`MyComic-unsigned-ipa`

### 下载 IPA

1. 打开 [Actions 页面](https://github.com/desire668/mycomic/actions/workflows/build-ipa.yml)
2. 点击最新一次绿色 `Build Unsigned IPA` 运行
3. 页面底部 **Artifacts** → 下载 `MyComic-unsigned-ipa`（需要登录 GitHub）
4. 解压后得到 `MyComic-unsigned.ipa`

若通过 Release 触发，也可直接在该 Release 的 Assets 中下载 `MyComic-unsigned.ipa`。

---

## 自行签名安装教程

未签名 IPA 无法直接安装，需要使用你自己的 Apple ID 签名。以下方式任选其一。

> 通用前提：免费 Apple ID 签名的应用 **7 天过期**（付费开发者账号为 1 年）；免费账号同时最多签名 3 个应用；过期后重新签名即可，数据通常保留。请勿使用共享/来源不明的 Apple ID。

### 方式一：AltStore（Windows / macOS，推荐长期使用）

1. 电脑安装 [AltServer](https://altstore.io/)，手机安装 AltStore（首次需用 AltServer 安装到手机）。
2. 手机与电脑连接同一 Wi-Fi，或使用 USB 数据线。
3. 在电脑托盘的 AltServer 图标中选择 **Install AltStore → 你的设备**，输入 Apple ID 完成安装。
4. 手机打开 **设置 → 通用 → VPN 与设备管理**，信任你的开发者证书。
5. 把 `MyComic-unsigned.ipa` 传到手机（AirDrop / 文件 App / iCloud 均可），在文件 App 中点击 IPA → 分享 → **AltStore**；或在 AltStore 的 *My Apps* 页点击左上角 `+` 选择该 IPA。
6. 输入 Apple ID 与密码完成签名安装。
7. 保持 AltServer 在同一网络运行，AltStore 会每 7 天自动续签。

### 方式二：Sideloadly（Windows / macOS，操作最简单）

1. 下载安装 [Sideloadly](https://sideloadly.io/) 与 iTunes（Windows 需要）。
2. 用数据线连接 iPhone / iPad，解锁并在手机上点「信任此电脑」。
3. 打开 Sideloadly，把 `MyComic-unsigned.ipa` 拖入 **IPA** 栏。
4. 填写 **Apple ID**，点击 **Start**，输入密码（如开启双重认证，需使用专用 App 密码）。
5. 安装完成后，进入 **设置 → 通用 → VPN 与设备管理 → 开发者 App**，点击你的 Apple ID 并选择「信任」。
6. 回到桌面打开 MyComic。7 天后如需继续使用，用同样步骤重新签名安装。

### 方式三：SideStore（免电脑续签，进阶）

1. 按 [SideStore 官方文档](https://sidestore.io/) 使用 AltServer / Jitterbug 等方式首次安装 SideStore 并配对。
2. 将 `MyComic-unsigned.ipa` 保存到「文件」App。
3. 在 SideStore 中点击 `+`，选择该 IPA，使用你的 Apple ID 签名安装。
4. SideStore 可通过 WireGuard 在本机完成 7 天续签，无需电脑常驻。

### 方式四：爱思助手（Windows）

1. 安装最新版[爱思助手](https://www.i4.cn/)，用数据线连接设备并在手机上信任电脑。
2. 打开「工具箱 → IPA 签名」，添加 `MyComic-unsigned.ipa`。
3. 使用自己的 Apple ID 登录（爱思助手会调用 Apple 签名服务），点击「开始签名」。
4. 签名完成后在「已签名 IPA」中点击安装到设备。
5. 首次打开如提示未受信任，进入 **设置 → 通用 → VPN 与设备管理** 信任对应证书。

### 安装失败排查

| 现象 | 处理 |
| --- | --- |
| 提示「无法安装，请稍后重试」 | Apple ID 未完成双重认证、密码错误，或短时间内签名次数过多，换网络/稍后再试 |
| 桌面图标灰色 / 无法打开 | 未信任证书：设置 → 通用 → VPN 与设备管理 → 信任 |
| 打开即闪退 | 设备 iOS 低于 15.0；或 IPA 未正确签名，请重新签名 |
| 7 天后无法打开 | 免费账号证书过期，重新签名安装即可 |
| AltStore 提示找不到设备 | 确认电脑与手机同一 Wi-Fi，或改用 USB 连接并安装 iTunes 驱动 |

---

## 常见问题

**Q：为什么不直接提供已签名 IPA？**
A：签名必须绑定你自己的 Apple ID 与设备，任何人的证书都无法通用；本项目按合规要求只提供未签名 IPA。

**Q：网站需要登录/付费怎么办？**
A：应用内直接加载官方网站，登录、注册、付费与访问控制完全由网站处理，应用不做任何绕过。

**Q：会不会收集我的数据？**
A：不会。应用没有账号系统、统计 SDK 或广告 SDK，Cookie 与缓存仅保存在本机，可在设置中清除。

**Q：为什么 iPad 上显示的是桌面版布局？**
A：iPadOS 的 WKWebView 默认使用桌面版 User-Agent，网站会返回响应式桌面布局，功能与网页一致。

**Q：构建失败怎么办？**
A：在 Actions 运行页面下载 `build-log` Artifact 查看完整 `xcodebuild` 日志；常见原因是 Xcode 版本变化或工程文件损坏。

---

## 合规与免责声明

- 本项目为第三方浏览器客户端，与 mycomic.com 无隶属关系，不代表网站官方立场。
- 应用不存储、不转载、不分发任何漫画内容；所有页面、图片与数据均来自官方网站。
- 不绕过登录验证、付费机制、访问控制或 DRM。
- 漫画内容版权归原作者及权利方所有，请遵守当地法律法规与网站使用条款。
- 本项目仅用于技术学习与个人使用，请自行承担使用风险。
