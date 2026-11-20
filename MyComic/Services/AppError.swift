//
//  AppError.swift
//  MyComic
//
//  Unified error type used by the network layer, parsers and view models.
//

import Foundation

enum AppError: LocalizedError, Equatable {
    /// No usable network connection.
    case offline
    /// Request timed out.
    case timedOut
    /// HTTP status that is not handled elsewhere.
    case http(Int)
    /// Cloudflare challenge / WAF block was returned.
    case cloudflareRequired(Int)
    /// Page was fetched but its structure could not be understood.
    case parse(String)
    /// The request was cancelled by the caller.
    case cancelled
    case invalidURL
    case other(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "网络未连接"
        case .timedOut:
            return "连接超时"
        case let .http(code):
            if code == 404 { return "内容不存在 (404)" }
            if code == 403 { return "访问被拒绝 (403)" }
            return "服务器错误 (\(code))"
        case .cloudflareRequired:
            return "需要 Cloudflare 验证"
        case let .parse(message):
            return message
        case .cancelled:
            return "请求已取消"
        case .invalidURL:
            return "地址无效"
        case let .other(message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .offline:
            return "请检查 Wi-Fi 或蜂窝网络后重试。"
        case .timedOut:
            return "网络响应时间过长，请稍后重试。"
        case let .cloudflareRequired(code):
            return "网站启用了 Cloudflare 防护（HTTP \(code)），请先完成交互验证后重试。"
        case .parse:
            return "页面结构可能已变化，或该内容需要登录后查看。"
        case .http(404):
            return "该漫画或章节可能已下架。"
        case .http:
            return "请稍后重试。"
        default:
            return nil
        }
    }

    var isCloudflare: Bool {
        if case .cloudflareRequired = self { return true }
        return false
    }

    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
