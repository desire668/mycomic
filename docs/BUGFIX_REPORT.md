# MyComic 原生 iOS 专项 Bug 修复报告

本文记录两个线上问题的定位、修复与验证过程。

- Bug 1：不同漫画的章节列表相同，章节内容与漫画不匹配。
- Bug 2：进入阅读器后底部 TabBar 没有隐藏。

## 1. 根本原因

### 1.1 Bug 1：章节列表串数据

通过对真实页面 HTML 的分析（`https://mycomic.com/cn/comics/{id}`）确认：

1. 漫画自己的章节列表由服务端写入 Alpine 组件的 `x-data` 属性：

   ```html
   <div x-data="{ chapters: [{&quot;id&quot;:817597,&quot;title&quot;:&quot;第1150话&quot;}, ...] }">
     <div class="grid grid-cols-3 ...">
       <template x-for="chapter in chapters">...</template>
     </div>
   </div>
   ```

   该数组只包含当前漫画的章节（服务端渲染，无需 JavaScript）。

2. 同一个详情页还包含全站「最近更新」侧栏，其链接指向**其他漫画的章节**：

   ```html
   <h3>最近更新</h3>
   <a href="/cn/comics/7580">一拳超人</a>
   <a href="/cn/chapters/xxxxx">第 xx 话</a>
   ```

3. 旧实现 `MyComicParser.parseChapters` 会在**整个文档**中扫描所有
   `a[href*="/cn/chapters/"]`。章节网格由 Alpine `x-for` 渲染，服务端 HTML
   中只有 `<template>` 占位内容，因此扫描结果主要来自「最近更新」侧栏：
   - 每本漫画都得到几乎相同的全站章节链接；
   - 章节名称与当前漫画不符；
   - 点击后打开的是其他漫画的章节；
   - `<template>` 内的占位链接（`/cn/comics/1` 等）也会被误收集。

4. `ComicRepository.readerContext` 之前没有校验章节页面「返回目录」指向的
   漫画，因此错误的章节链接仍能直接进入阅读器。

结论：**根因是解析作用域错误（全文档扫描）+ 章节归属未校验，而不是缓存复用。**

### 1.2 Bug 2：阅读器底部 TabBar 未隐藏

阅读器此前通过 `NavigationLink` push 到 TabView 内部的 NavigationView：

```swift
NavigationLink(destination: ReaderView(route: ...)) { ... }
```

`ReaderView` 中的 `.navigationBarHidden(true)` 只隐藏了导航栏，系统
`TabView` 的 TabBar 仍然存在，因此阅读区域被底部导航占用。

## 2. 修改文件清单

| 文件 | 修改内容 |
| --- | --- |
| `MyComic/Services/MyComicParser.swift` | 重写章节解析：优先解析 `x-data` 中的章节 JSON 数组；回退时只接受章节网格（`grid-cols*` 容器）内的链接；新增括号匹配与实体反转义；彻底移除全文档章节链接扫描 |
| `MyComic/Repositories/ComicRepository.swift` | `readerContext` 校验章节页面「返回目录」的 comicId，与当前漫画不一致时抛出解析错误，不再展示其他漫画内容 |
| `MyComic/ViewModels/DetailViewModel.swift` | 增加请求代号（generation），旧请求/取消请求不得覆盖当前界面状态 |
| `MyComic/Views/Detail/DetailView.swift` | 阅读器入口由 `NavigationLink` 改为 `fullScreenCover(item:)`；“开始阅读/继续阅读”与章节按钮统一使用全屏阅读 |
| `MyComic/Views/Home/HomeView.swift` | 「继续阅读」卡片改为 `fullScreenCover` 打开阅读器 |
| `MyComic/Views/Shelf/ShelfView.swift` | 阅读历史条目改为 `fullScreenCover` 打开阅读器 |
| `MyComic/Views/Reader/ReaderView.swift` | 增加 `.statusBar(hidden: !viewModel.showBars)`，工具栏隐藏时状态栏一并隐藏 |
| `Tests/MyComicTests/ParserTests.swift` | 更新详情页 Fixture 为真实结构（`x-data` + `最近更新` 侧栏）；新增章节归属回归用例 |

## 3. 章节数据关联修复方法

1. **以漫画作用域的数据为唯一来源**：从详情页第一个包含 `chapters:` 的
   `x-data` 属性中提取 JSON 数组，使用括号匹配（忽略字符串内的 `[`/`]`）、
   反转义 `&quot;` 后交给 `JSONDecoder`，再映射为 `Chapter(id:title:)` 并去重。
2. **回退策略也是漫画作用域的**：若页面没有 `x-data`，只接受位于
   `grid-cols*` 章节容器内的 `/cn/chapters/{id}` 链接，并跳过 `<template>`、
   「开始阅读/上一话/下一话/返回目录」等导航链接。
3. **找不到就返回空**：不再退回到全站链接，UI 会显示「暂无章节」，不会
   展示其他漫画的数据。
4. **阅读前二次校验**：章节页面解析出「返回目录」漫画 ID 后，与路由中的
   comicId 比较；不一致直接报错。
5. **章节与图片同源**：章节图片 URL 必须包含 `/chapters/{chapterId}/`，
   阅读器只展示当前章节的图片（解析器原有规则，已由测试覆盖）。

## 4. 缓存隔离

- `ComicRepository` 的详情缓存以 `comicId` 为键，本身不会跨漫画复用；
- 本次新增 ViewModel 请求代号，确保快速切换漫画时旧请求不会晚到覆盖新界面；
- 章节列表不再来自任何全局数组或共享缓存，每次详情解析结果都携带自己的
  章节集合。

## 5. TabBar 隐藏实现方式（iOS 15 兼容）

采用「方案 A：阅读器独立全屏呈现」：

- 三个入口（详情页、首页继续阅读、书架历史）全部改为
  `.fullScreenCover(item: $readerRoute)`；
- 阅读器不再位于 TabView 的导航栈内，因此系统 TabBar、导航栏都不会显示；
- 阅读器内部自绘顶栏/底栏，点击画面切换显示；
- 退出 `fullScreenCover` 后自动回到原页面，TabBar 正常恢复；
- 未使用 iOS 16 才支持的 `.toolbar(.hidden, for: .tabBar)`，最低版本仍为 iOS 15。

### 安全区域处理

- 阅读内容使用 `Color.black.ignoresSafeArea()` 作为背景，图片区域由
  `GeometryReader` 的可用尺寸决定；
- 顶部/底部工具栏位于安全区内，不遮挡刘海、动态岛与 Home Indicator；
- 工具栏隐藏时状态栏一并隐藏，阅读区域最大化。

## 6. iOS 15 兼容性

| API | 可用版本 | 说明 |
| --- | --- | --- |
| `fullScreenCover(item:)` | iOS 14 | 替代 NavigationLink 全屏呈现 |
| `statusBar(hidden:)` | iOS 13 | 工具栏隐藏时隐藏状态栏 |
| `LazyVGrid` / `ScrollView` | iOS 14 / 13 | 阅读器与列表布局 |
| `.toolbar(.hidden, for: .tabBar)` | **未使用** | 仅 iOS 16 可用 |

## 7. 实际测试结果

### 7.1 章节数据（真实站点）

详细信息见 [BUGFIX_CHAPTERS.md](BUGFIX_CHAPTERS.md)。对 5 本漫画逐本读取
线上详情页的章节数组，并打开真实章节页核对图片：

| comicId | 漫画 | 章节数 | 抽样章节 | 图片校验 |
| --- | --- | --- | --- | --- |
| 1128 | ONE PIECE航海王 | 473 | 814565 | 15 张，全部 `/chapters/814565/` |
| 7580 | 一拳超人 | 286 | 788244 | 21 张，全部 `/chapters/788244/` |
| 50676 | 女神的足下 | 1 | 728899 | 9 张，全部 `/chapters/728899/` |
| 6591 | 一弦定音！ | 131 | 807274 | 29 张，全部 `/chapters/807274/` |
| 10746 | 魔技科的剑士与召唤魔王 | 65 | 816498 | 13 张，全部 `/chapters/816498/` |

五本漫画的章节数量、首尾章节 ID 与名称均不同，且章节图片与章节 ID 完全匹配。

### 7.2 单元测试

新增/更新以下回归用例（`Tests/MyComicTests/ParserTests.swift`）：

- `testDetailParsing`：详情页含 `x-data` 章节数组与「最近更新」侧栏时，只返回
  当前漫画章节，且不包含侧栏章节（7777）。
- `testDetailChaptersFallbackToChapterGrid`：无 `x-data` 时只解析
  `grid-cols*` 章节容器内的链接。
- `testDetailNeverUsesSidebarChapters`：页面只有「最近更新」侧栏时返回空章节，
  而不是其他漫画章节。

GitHub Actions 运行记录（提交 `55849e5`）：
<https://github.com/desire668/mycomic/actions/runs/44706386623>

| Job | 结果 |
| --- | --- |
| Unit tests (iOS Simulator) | ✅ success（全部单元测试通过） |
| Build MyComic (unsigned) | ✅ success（Release 编译 + 打包 IPA + 发布 `unsigned-latest`） |

### 7.3 阅读器 UI

- 三个入口全部改为 `.fullScreenCover`，阅读器不再位于 TabView 导航栈内，
  系统 TabBar/导航栏不会出现；退出后自动恢复。
- `.statusBar(hidden:)` 与自绘工具栏联动。
- 该行为已通过 Release 编译验证；实际视觉与手势需在真机/模拟器安装 IPA 后确认。

发布产物（滚动更新，标签 `unsigned-latest`）：
<https://github.com/desire668/mycomic/releases/download/unsigned-latest/MyComic-unsigned.ipa>

## 8. 尚未解决的问题

1. 站点关闭 JavaScript 时，章节网格本身不会渲染；本实现依赖服务端写入的
   `x-data` 数组，这是目前唯一可靠且与漫画绑定的服务端数据。若站点改版移除
   该结构，需要重新分析页面。
2. 「单行本（卷）」数据不在章节列表中（与站点「单话」分区一致）；如需阅读
   单行本，应作为独立分区后续实现。
3. 本章节修复无法绕过 Cloudflare；如遇验证拦截，仍按既有交互验证流程处理。
4. 阅读器的沉浸式效果（TabBar 隐藏、状态栏联动）已完成代码与编译验证，
   尚未在真机上进行视觉回归测试。
