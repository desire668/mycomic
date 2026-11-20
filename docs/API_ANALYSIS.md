# MyComic 接口分析报告

> 分析对象：`https://mycomic.com/cn`
> 分析时间：2026-11-20
> 参考实现：[venera-configs/mycomic.js](https://github.com/venera-app/venera-configs/blob/main/mycomic.js)（仅作为功能与选择器参考，未复制其代码）

## 0. 结论摘要

1. **MyComic 没有对公众开放的 JSON API。** 站点是服务端渲染的 Laravel/Livewire（Flux UI）+ Alpine.js 页面，唯一结构化的数据是页面内嵌的 Alpine `x-data` 章节数组。本项目采用 **原生 HTTP 请求 + HTML 解析** 获取数据。
2. **所有页面请求受 Cloudflare 防护。** 从数据中心 IP / 非浏览器 TLS 指纹发起的直连会得到 `403 Sorry, you have been blocked`（WAF 硬拦截）；从普通浏览器访问会先出现约 10–15 秒的 Cloudflare 交互验证，验证通过后正常返回页面。
3. **图片 CDN 独立于主站，不带 Cloudflare 挑战，但强制校验 `Referer: https://mycomic.com/`。** 缺少 Referer 返回 `403`（响应体 3 字节纯文本）；带正确 Referer 返回 `200 image/jpeg`。
4. 站点存在登录/注册（Laravel 表单），收藏（`/cn/bookmarks`）需要登录；观看记录（`/cn/records`）游客态也可显示（站点用 `user_uuid` cookie 追踪）。
5. 未发现站点提供公开的收藏/记录 JSON 接口；本项目书架与阅读进度以**本地存储**为主，并明确标注"本地书架"，不伪装服务器同步。

---

## 1. 验证环境与方法

| 项目 | 说明 |
|---|---|
| 页面结构验证 | 真实浏览器（Chromium）打开线上页面，记录 DOM 结构、类名、属性与链接 href |
| 图片链路验证 | 命令行 HTTP 请求 `biccam.com`，验证带/不带 Referer 的状态码与内容类型 |
| 主站直连验证 | 命令行 HTTP 请求 `mycomic.com`，验证 Cloudflare 拦截行为 |
| 参考实现 | venera `mycomic.js` v1.1.0（已阅读全文，提取选择器与请求头约定） |

> **重要限制**：本次分析所处的网络出口为数据中心 IP，主站 `mycomic.com` 对其返回 Cloudflare WAF 403，因此页面级接口由真实浏览器验证；`URLSession` 在真实 iOS 设备（住宅网络 + WKWebView 取得 `cf_clearance`）上的可用性无法在当前环境完成端到端测试，App 内已实现完整的检测与提示逻辑，详见第 6 节。

---

## 2. 基础信息

| 项目 | 值 |
|---|---|
| 站点根 | `https://mycomic.com` |
| 中文站前缀 | `https://mycomic.com/cn` |
| 图片 CDN | `https://biccam.com` |
| 页面技术栈 | Laravel + Livewire/Flux + Alpine.js + Tailwind CSS |
| 语言参数 | 路径中的 `/cn` |
| 分页 | 查询参数 `page=N`（每页 30 条） |
| 页面编码 | UTF-8 |

---

## 3. 已实现并验证的接口清单

### 3.1 漫画列表（分类 / 排序 / 搜索共用）

| 项目 | 内容 |
|---|---|
| 地址 | `GET https://mycomic.com/cn/comics` |
| 请求参数 | `page`（页码，≥2 时出现）、`sort`（`-update` 最近更新、`-views` 最高人气；缺省为最新上架）、`q`（关键词）、`filter[tag]` / `filter[country]` / `filter[audience]` / `filter[year]` / `filter[end]` |
| 请求头 | 浏览器 UA、`Accept-Language: zh-CN,zh;q=0.9`、会话 Cookie（如已取得 `cf_clearance`） |
| 返回格式 | `text/html` |
| 分页 | 每页 30 条；末页链接形如 `...?page=1845` |
| 认证 | 不需要（Cloudflare 验证除外） |
| 状态 | ✅ 已验证（排序、筛选、搜索、分页均在真实浏览器确认） |

已验证的排序参数：

| 标签 | URL |
|---|---|
| 最新上架（默认） | `/cn/comics` |
| 最近更新 | `/cn/comics?sort=-update` |
| 最高人气 | `/cn/comics?sort=-views` |

已验证的筛选参数（示例值均为站点真实链接）：

| 分组 | 参数 | 已验证示例 |
|---|---|---|
| 作品类型 | `filter[tag]` | `mohuan`（魔幻）、`mofa`（魔法） |
| 作品地区 | `filter[country]` | `japan`（日本）、`hongkong`（港台） |
| 适合受众 | `filter[audience]` | `shaonv`（少女）、`shaonian`（少年）、`qingnian`（青年） |
| 出品年份 | `filter[year]` | `2026`、`2025` |
| 目前进度 | `filter[end]` | `0`（连载中）、`1`（已完结） |

> 筛选值使用拼音 slug。完整选项列表由列表页侧边栏动态解析（所有分组链接均带上述参数），不在代码中硬编码全量枚举；仅保留已验证示例作为解析失败时的兜底。

**卡片 HTML 结构（已验证，来自 `/cn/comics?sort=-update&page=2`）：**

```html
<div class="grid grid-cols-3 md:grid-cols-6 ... mb-12">
  <div class=" group relative">
    <div class="aspect-w-3 aspect-h-4 w-full ...">
      <a href="https://mycomic.com/cn/comics/51102">
        <img src="https://biccam.com/comics/51102-03ed0c.jpg"
             fetchpriority="high" alt="狼同学的秘密" class="...">
        <div class="absolute top-0 left-0 ...">
          <div class="text-white text-sm pb-3 truncate">第16话</div>
        </div>
      </a>
    </div>
    <div class="mt-2 text-center">
      <div class="text-sm text-zinc-500 ... truncate" data-flux-subheading="">狼同学的秘密</div>
    </div>
  </div>
</div>
```

解析规则（已在 Swift 中实现）：

- 遍历 `a[href]`，匹配 `/cn/comics/(\d+)`；
- 其内部必须存在 `img`，且 `src`（或 `data-src`）包含 `biccam.com/comics/`；
- 标题优先取 `img[alt]`；
- 最新章节取 `a` 内第一个 class 含 `truncate` 的 `div` 文本（如 `第16话`）；
- 按漫画 id 去重，保留 DOM 顺序；
- 最大页码：全文正则 `page=(\d+)` 取最大值。

**脱敏请求示例：**

```http
GET /cn/comics?sort=-update&page=2 HTTP/1.1
Host: mycomic.com
User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.9
Cookie: cf_clearance=<已脱敏>
```

**响应样本（截取，已脱敏）：**

```html
<div class="grid grid-cols-3 md:grid-cols-6 gap-x-2 ...">
  <div class=" group relative"> ... <a href="https://mycomic.com/cn/comics/51102">
    <img src="https://biccam.com/comics/51102-03ed0c.jpg" alt="狼同学的秘密">
    ...
    <div class="text-white text-sm pb-3 truncate">第16话</div>
  </a> ... </div>
  <!-- 每页共 30 个卡片 -->
</div>
<nav role="navigation" aria-label="Pagination Navigation" ...>
  <a href="...?sort=-update&page=3">下一页 »</a>
  <a href="...?sort=-update&page=1845">1845</a>
</nav>
```

### 3.2 搜索

| 项目 | 内容 |
|---|---|
| 地址 | `GET /cn/comics?q=关键词` |
| 已验证样本 | `https://mycomic.com/cn/comics?q=one` → 30 条结果，共 6 页，下一页 `/cn/comics?q=one&page=2` |
| 标记 | ✅ 已验证 |
| 空结果 | 页面不输出"无结果"文案，只能通过"卡片数为 0"判断 |
| 说明 | 搜索结果与普通列表页使用完全相同的卡片结构，复用同一解析器 |

### 3.3 漫画排行

| 项目 | 内容 |
|---|---|
| 地址 | `GET https://mycomic.com/cn/rank` |
| 参数 | `sort=-week`（週排行）、`sort=-month`（月排行）、`sort=-views`（历史排行）；日排行为无参数默认 |
| 返回格式 | `text/html`（表格） |
| 分页 | 无，固定 50 条 |
| 封面 | 表格中**没有**封面图，也没有阅读量字段 |
| 标记 | ✅ 已验证 |

表格行结构（已验证）：

```html
<table class="[:where(&)]:min-w-full table-fixed ...">
  <tr data-flux-row="">
    <td data-flux-cell="" class="..."><div data-flux-badge>1</div></td>
    <td data-flux-cell="" class="..."><a href="/cn/comics/54348">美丽新世界！</a></td>
    <td data-flux-cell="" class="..."><a href="/cn/comics?filter[author]=...">作者</a></td>
    <td data-flux-cell="" class="..."><a href="/cn/chapters/794527">最新话</a></td>
    <td data-flux-cell="" class="...">2025-01-01</td>
    <td data-flux-cell="" class="...">4.00</td>
  </tr>
</table>
```

解析规则：遍历 `tr`，取第一个 `a[href*='/cn/comics/']`（路径精确为 `/cn/comics/{id}`，排除带 query 的作者链接）作为条目；排名取行首数字；作者取 `href` 含 `filter[author]` 的链接；最新章节取 `href` 含 `/cn/chapters/` 的链接；评分取形如 `4.00` 的最后单元格。

### 3.4 漫画详情

| 项目 | 内容 |
|---|---|
| 地址 | `GET /cn/comics/{comicId}`（示例 `1128`） |
| 返回格式 | `text/html` |
| 章节列表 | **服务端写入 Alpine `x-data` 的章节 JSON 数组**（示例 1128 为 473 个可读章节），详情页不再依赖客户端渲染即可解析；「共 603 话」是作品元数据，与实际可读章节数可能不同 |
| 排序 | 站点是前端 Alpine.js 对章节数组做 `reverse()`，无服务端排序参数 |
| 收藏 | 详情页有"加入收藏"按钮（Alpine `isSynced` 控制），未登录点击后按钮直接隐藏，无接口可见 |
| 标记 | ✅ 已验证 |

已验证的数据字段（示例 ONE PIECE 航海王）：

| 字段 | 值 |
|---|---|
| 标题 | `ONE PIECE航海王` |
| 作者 | `尾田榮一郎` |
| 状态 | `连载中` |
| 地区 | `日本` |
| 标签 | `热血`、`冒险`、`格斗`、`少年` |
| 封面 | `https://biccam.com/comics/1128-6f942d.jpg` |
| 章节数 | `共 603 话` |
| 第一章链接 | `https://mycomic.com/cn/chapters/9832`（章节数组最后一项） |
| 开始阅读 | `https://mycomic.com/cn/chapters/9771`（服务端推荐位，**不属于该漫画的章节数组**） |

解析规则：

- 标题：`<meta property="og:title">`，兜底 `h1` 或 `<title>` 去掉站点后缀；
- 封面：`<meta property="og:image">`；
- 简介：`<meta name="description">` / `og:description`；
- 作者：`a[href*='filter[author]']` 或 `filter%5Bauthor%5D` 的链接文本；
- 标签：`a[href*='filter[tag]']` / `filter%5Btag%5D`；
- 地区：`a[href*='filter[country]']`；
- 状态：`a[href*='filter[end]']` 文本，兜底正文"连载中/已完结"；
- 章节：解析第一个包含 `chapters:` 的 `x-data` 属性，取出 `[{id,title}]` JSON 数组（先做 HTML 实体反转义），按 id 去重；**禁止全文档扫描 `a[href*='/cn/chapters/']`**，因为页面还含全站「最近更新」侧栏，其链接属于其他漫画，会导致不同漫画显示相同章节；
- 回退：页面缺少 `x-data` 时，只接受 `grid-cols*` 章节容器内的链接，并跳过 `<template>` 与「开始阅读/上一话/下一话/返回目录」；
- 「开始阅读」按钮的服务端默认链接可能指向推荐章节（如 1128 的 `/cn/chapters/9771`），不属于该漫画章节数组，不能作为章节来源；
- 章节数：正则 `共\s*(\d+)\s*话`，兜底为去重后章节数。

### 3.5 章节阅读图片

| 项目 | 内容 |
|---|---|
| 地址 | `GET /cn/chapters/{chapterId}`（已验证示例 `814565`，属于 1128 第1148话） |
| 返回格式 | `text/html`，页面直接包含全部 `<img>`（示例 15 页，非懒加载、无 data-src） |
| 图片地址 | `https://biccam.com/chapters/{chapterId}/{pageNo}-{hash}.jpg` |
| 已验证样本 | `https://biccam.com/chapters/814565/1-777d0c.jpg`、`/2-e85334.jpg`、`/3-bee0e4.jpg` |
| 图片格式 | 统一 `image/jpeg`（CDN 不做 WebP 转换，`cf-polished: format_not_supported`） |
| 标记 | ✅ 已验证 |

解析规则：

- 收集 `img.page`（class 含 `page`）且 `src` 含 `biccam.com/chapters/` 的元素；
- 兜底：任意 `img` 的 `src` / `data-src` 含 `biccam.com/chapters/`；
- 按 URL 中的页号数字排序（兜底 DOM 顺序），去重；
- 上一话/下一话：文本为"上一话/下一话"且 `href` 含 `/cn/chapters/` 的链接（首话的上一话为 disabled）；
- 目录：`a[href*='/cn/comics/']` 中文本为"返回目录"者。

**图片请求验证结果：**

| 请求 | 结果 |
|---|---|
| `GET https://biccam.com/chapters/9771/1-c57cb5.jpg` + `Referer: https://mycomic.com/` + 浏览器 UA | `200`，`image/jpeg`，187,690 字节 |
| 同上，去掉 Referer | `403`，3 字节纯文本 |
| `GET https://biccam.com/comics/1128-6f942d.jpg` + Referer | `200`，`image/jpeg`，26,635 字节 |
| 同上，去掉 Referer | `403` |
| `Accept: image/webp` 协商 | 仍返回 `image/jpeg`（无 WebP） |

> App 内所有图片请求固定携带 `Referer: https://mycomic.com/`、浏览器 UA、`Accept: image/avif,image/webp,image/apng,image/*,*/*;q=0.8`。

### 3.6 站点导航 / 页面清单

| 页面 | URL | 状态 |
|---|---|---|
| 主页 | `/cn` | ✅ 已验证：推荐给你 / 最近更新 / 最新上架 / 排行表 |
| 漫画资料库 | `/cn/comics` | ✅ 已验证 |
| 漫画排行 | `/cn/rank` | ✅ 已验证 |
| 我的收藏 | `/cn/bookmarks` | ✅ 已验证：未登录显示"未有记录..." + "登入以继续" |
| 观看记录 | `/cn/records` | ✅ 已验证：游客态显示记录表格（`user_uuid` cookie 追踪） |

### 3.7 用户登录（实验性，未端到端验证）

| 项目 | 内容 |
|---|---|
| 登录 | `POST https://mycomic.com/cn/login`，字段 `email`、`password`（Vue/axios 表单） |
| 注册 | `POST https://mycomic.com/cn/register`，字段 `name`、`email`、`password`、`password_confirmation` |
| 找回密码 | `POST https://mycomic.com/cn/forget`，字段 `email` |
| 会话 | Laravel session Cookie + `XSRF-TOKEN`；请求需带 `X-XSRF-TOKEN` 头 |
| 标记 | ⚠️ **待验证**：表单地址与字段名已从真实页面确认，但登录成功后的返回结构、错误码未验证（无测试账号）；本项目默认使用本地书架，不依赖登录 |

### 3.8 未发现 / 待验证

| 项目 | 状态 |
|---|---|
| 公开 JSON/XHR API（如 `/api/comics`） | ❌ 未发现；页面为服务端渲染，未观察到业务 XHR |
| 收藏增删接口 | ⚠️ 待验证（按钮为 Alpine 前端状态，未捕获到请求） |
| 观看记录上报接口 | ⚠️ 待验证（游客记录由站点自身脚本上报） |
| 用户信息接口 | ⚠️ 待验证 |

---

## 4. Cloudflare 防护分析

### 4.1 实测行为

| 场景 | 结果 |
|---|---|
| 数据中心 IP + curl/Invoke-WebRequest + Chrome UA 直连 `/cn` | `403`，`Server: cloudflare`，响应体为 `Sorry, you have been blocked`（WAF 硬拦截，非 JS 挑战） |
| 真实浏览器访问 `/cn` | 先出现"正在进行安全验证"页面，约 13 秒后自动通过并展示首页 |
| 真实浏览器访问 `/cn/bookmarks` | 正常（已通过挑战），无 `cf_clearance` 出现在 `document.cookie`（HttpOnly） |
| 图片 CDN `biccam.com` | 不触发 Cloudflare 挑战，仅校验 Referer |

### 4.2 对客户端的影响

1. `URLSession` 直连可能收到 `403`（WAF 或挑战），必须实现检测与用户引导；
2. `cf_clearance` 为 HttpOnly，`document.cookie` 读不到，必须通过 `WKHTTPCookieStore` 读取；
3. `cf_clearance` 与 IP、User-Agent 绑定，且会过期；App 必须在同一个 WKWebView 会话中完成验证后立即同步 Cookie，并在后续请求中使用与验证时**一致的 UA**；
4. 无法保证同步后 100% 可用（TLS 指纹差异），因此验证后必须**重新请求并据实反馈**，不能假定成功。

### 4.3 App 内实现策略

- `APIClient` 检测：HTTP `403`/`503` + 响应体标记（`Just a moment`、`challenge-platform`、`cf-browser-verification`、`Attention Required`、`cf-error-details`、`__cf_chl`）；
- 抛出 `AppError.cloudflareRequired`，界面展示"进行 Cloudflare 验证"入口；
- 用户在独立 `WKWebView`（仅验证用途）中完成验证；
- 用户点击"完成并同步"后，将 `mycomic.com` 域下全部 Cookie 写入 `HTTPCookieStorage`，记录该 WKWebView 的 UA 供 `APIClient` 使用；
- 立即重试原请求；仍失败则如实提示"验证未生效（可能受 IP/UA 限制）"。

---

## 5. 请求头约定（已验证）

```http
User-Agent: <与 WKWebView 验证时一致，默认为 iOS Safari UA>
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.9
Referer: https://mycomic.com/
```

图片请求：

```http
User-Agent: <同上>
Accept: image/avif,image/webp,image/apng,image/*,*/*;q=0.8
Referer: https://mycomic.com/
```

> `Referer` 已在图片链路实测为必需项；页面请求的 Referer 与 UA 依据真实浏览器行为设置，未做导致失败的假设。

---

## 6. 已知限制

1. 本报告中的页面级验证来自真实浏览器；`URLSession` 在真实 iOS 设备上的端到端可用性无法在当前分析环境中证明（出口 IP 被 WAF 拦截）。
2. 章节图片 CDN 无 `cf_clearance` 要求，但强制 Referer；Referer 缺失即 `403`。
3. 站点无公开 JSON API，HTML 结构变更会导致解析失败；App 已对空结果、字段缺失做容错并在界面提示。
4. 登录与收藏同步为实验性实现（表单地址已确认，成功响应未验证）；默认使用本地书架。
5. 排行页无封面与阅读量字段，App 不虚构这些数据。
