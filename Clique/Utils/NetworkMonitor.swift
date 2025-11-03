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

    /// Whether the connection is expensive (metered, roaming, hotspot, etc.)
    private(set) var isExpensive: Bool = false

    /// Whether Low Data Mode is enabled
    private(set) var isConstrained: Bool = false

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
        // Don't start automatically - wait for explicit start() call
    }

    /// Starts network monitoring
    ///
    /// Call this explicitly during app initialization to begin tracking network state.
    /// Monitoring continues until the NetworkMonitor is deallocated.
    func start() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            Task { @MainActor in
                let wasConnected = self.isConnected
                let previousType = self.connectionType

                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

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
                    let flags = [
                        self.isExpensive ? "expensive" : nil,
                        self.isConstrained ? "constrained" : nil
                    ].compactMap { $0 }.joined(separator: ", ")

                    let flagsStr = flags.isEmpty ? "" : " (\(flags))"
                    print("📡 Network changed: \(self.connectionType) (connected: \(self.isConnected))\(flagsStr)")
                }
            }
        }

        monitor.start(queue: queue)
    }

    /// Recommends optimal video quality based on current network conditions
    ///
    /// Takes into account connection type, Low Data Mode, and expensive connection flags.
    ///
    /// - Returns: Recommended `ImageQuality` for video playback
    func recommendedVideoQuality() -> ImageQuality {
        // Priority 1: Respect system Low Data Mode
        if isConstrained {
            return .low
        }

        // Priority 2: On expensive connections (metered, roaming, hotspot), save data
        if isExpensive {
            return .medium
        }

        // Priority 3: Connection type determines quality
        switch connectionType {
        case .wifi, .ethernet:
            // Fast, unlimited connections get high quality
            return .high
        case .cellular:
            // Cellular defaults to medium (safe for most plans)
            return .medium
        case .unknown:
            // Unknown connections default to medium (conservative)
            return .medium
        }
    }

    deinit {
        monitor.cancel()
    }
}
