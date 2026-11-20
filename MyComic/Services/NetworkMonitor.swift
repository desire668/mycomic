//
//  NetworkMonitor.swift
//  MyComic
//
//  Lightweight NWPathMonitor wrapper used by the offline banner and the
//  settings screen.
//

import Foundation
import Network

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var hasDeterminedStatus: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mycomic.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hasDeterminedStatus = true
                self.isConnected = connected
                self.isExpensive = expensive
            }
        }
        monitor.start(queue: queue)
    }

    var statusDescription: String {
        isConnected ? "已连接网络" : "网络未连接"
    }

    var connectionTypeDescription: String {
        if !isConnected { return "离线" }
        return isExpensive ? "蜂窝网络 / 低数据模式" : "Wi-Fi 或高速网络"
    }

    deinit {
        monitor.cancel()
    }
}
