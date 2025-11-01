//
//  NetworkMonitor.swift
//  Clique
//
//  Created by Rod Tavangar on 12/10/24.
//  Updated by Assistant for network-adaptive video quality.
//

import Foundation
import Network
import Observation

/// Monitors network connectivity and type for adaptive video quality selection
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.clique.networkmonitor")

    /// Current network connection type
    private(set) var connectionType: ConnectionType = .unknown

    /// Whether the device is currently connected to a network
    private(set) var isConnected: Bool = false

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown

        /// Whether this connection type should prefer high quality video
        var prefersHighQuality: Bool {
            switch self {
            case .wifi, .ethernet:
                return true
            case .cellular, .unknown:
                return false
            }
        }
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            Task { @MainActor in
                let wasConnected = self.isConnected
                let previousType = self.connectionType

                self.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }

                // Only log on meaningful changes (not every path update)
                if wasConnected != self.isConnected || previousType != self.connectionType {
                    print("📡 Network changed: \(self.connectionType) (connected: \(self.isConnected))")
                }
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
