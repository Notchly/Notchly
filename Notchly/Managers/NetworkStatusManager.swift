//
//  NetworkStatusManager.swift
//  Notchly
//
//  Created by n0xbyte on 20.07.2026.
//

import Combine
import CoreWLAN
import Darwin
import Foundation

enum NetworkStatusKind: Equatable, Sendable {
    case wifiConnected
    case personalHotspot
    case internetRestored
    case noInternet
    case disconnected
    case wifiOff
}

struct NetworkStatusEvent: Equatable, Sendable {
    let kind: NetworkStatusKind
    let networkName: String?
}

private enum NetworkConnectionState: Equatable, Sendable {
    case unknown
    case wifiOff
    case disconnected
    case connected(networkName: String?, isPersonalHotspot: Bool, hasInternet: Bool)
}

private struct NetworkPathSnapshot: Equatable, Sendable {
    let isSatisfied: Bool
    let usesWiFi: Bool
    let isExpensive: Bool

    static let unknown = NetworkPathSnapshot(
        isSatisfied: false,
        usesWiFi: false,
        isExpensive: false
    )
}

@MainActor
final class NetworkStatusManager: NSObject, ObservableObject {
    @Published private(set) var eventID = 0
    @Published private(set) var currentEvent: NetworkStatusEvent?

    private let wifiClient = CWWiFiClient.shared()
    private let monitorQueue = DispatchQueue(
        label: "xyz.notchly.network-path-monitor",
        qos: .utility
    )

    private var pathMonitor: SystemNetworkPathMonitor?
    private var latestPath = NetworkPathSnapshot.unknown
    private var currentState = NetworkConnectionState.unknown
    private var hasResolvedInitialState = false
    private var refreshTask: Task<Void, Never>?
    private var probeTask: Task<Void, Never>?
    private var healthCheckTask: Task<Void, Never>?
    private var resolutionID = UUID()
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true

        wifiClient.delegate = self
        startMonitoringWiFiEvents()

        if let monitor = SystemNetworkPathMonitor() {
            pathMonitor = monitor
            monitor.start(queue: monitorQueue) { [weak self] snapshot in
                Task { @MainActor [weak self] in
                    self?.receive(path: snapshot)
                }
            }
        }
        scheduleRefresh(after: .milliseconds(200))
        startHealthChecks()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        refreshTask?.cancel()
        refreshTask = nil
        probeTask?.cancel()
        probeTask = nil
        healthCheckTask?.cancel()
        healthCheckTask = nil
        resolutionID = UUID()

        pathMonitor?.cancel()
        pathMonitor = nil

        try? wifiClient.stopMonitoringAllEvents()
        wifiClient.delegate = nil
    }

    private func startMonitoringWiFiEvents() {
        let eventTypes: [CWEventType] = [
            .powerDidChange,
            .ssidDidChange,
            .linkDidChange,
            .modeDidChange
        ]

        for eventType in eventTypes {
            try? wifiClient.startMonitoringEvent(with: eventType)
        }
    }

    private func receive(path: NetworkPathSnapshot) {
        guard latestPath != path else { return }
        latestPath = path
        scheduleRefresh()
    }

    private func scheduleRefresh(after delay: Duration = .milliseconds(280)) {
        guard isStarted else { return }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }

            self.refreshTask = nil
            self.resolveCurrentState()
        }
    }

    private func resolveCurrentState() {
        resolutionID = UUID()
        let activeResolutionID = resolutionID
        probeTask?.cancel()

        let interface = wifiClient.interface()
        let isPoweredOn = interface?.powerOn() ?? false

        guard isPoweredOn else {
            publish(.wifiOff)
            return
        }

        let networkName = interface?.ssid()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNetworkName = !(networkName?.isEmpty ?? true)
        let isAssociated =
            hasNetworkName ||
            interface?.interfaceMode() == .station ||
            latestPath.usesWiFi

        guard isAssociated else {
            publish(.disconnected)
            return
        }

        let isPersonalHotspot = latestPath.usesWiFi && latestPath.isExpensive

        guard latestPath.isSatisfied else {
            publish(.connected(
                networkName: networkName,
                isPersonalHotspot: isPersonalHotspot,
                hasInternet: false
            ))
            return
        }

        probeTask = Task { @MainActor [weak self] in
            var hasInternet = await Self.probeInternetConnection()

            if !hasInternet, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                hasInternet = await Self.probeInternetConnection()
            }

            guard !Task.isCancelled, let self else { return }
            guard self.resolutionID == activeResolutionID else { return }

            self.probeTask = nil
            self.publish(.connected(
                networkName: networkName,
                isPersonalHotspot: isPersonalHotspot,
                hasInternet: hasInternet
            ))
        }
    }

    private func publish(_ nextState: NetworkConnectionState) {
        guard currentState != nextState else { return }

        let previousState = currentState
        currentState = nextState

        guard hasResolvedInitialState else {
            hasResolvedInitialState = true
            return
        }

        guard let event = event(for: nextState, previousState: previousState) else { return }
        currentEvent = event
        eventID += 1
    }

    private func startHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let delay: Duration = self.currentState.isConnectedWithoutInternet
                    ? .seconds(20)
                    : .seconds(60)
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }

                guard self.currentState.isConnected,
                      self.latestPath.isSatisfied else { continue }
                self.resolveCurrentState()
            }
        }
    }

    private func event(
        for state: NetworkConnectionState,
        previousState: NetworkConnectionState
    ) -> NetworkStatusEvent? {
        switch state {
        case .unknown:
            return nil
        case .wifiOff:
            guard previousState != .wifiOff else { return nil }
            return NetworkStatusEvent(kind: .wifiOff, networkName: nil)
        case .disconnected:
            guard previousState != .disconnected else { return nil }
            return NetworkStatusEvent(kind: .disconnected, networkName: nil)
        case let .connected(networkName, isPersonalHotspot, hasInternet):
            if !hasInternet,
               !previousState.matchesConnected(isPersonalHotspot: isPersonalHotspot, hasInternet: false) {
                return NetworkStatusEvent(kind: .noInternet, networkName: networkName)
            }

            if hasInternet,
               previousState.isConnectedWithoutInternet {
                return NetworkStatusEvent(kind: .internetRestored, networkName: networkName)
            }

            if isPersonalHotspot,
               !previousState.matchesConnected(isPersonalHotspot: true, hasInternet: true) {
                return NetworkStatusEvent(kind: .personalHotspot, networkName: networkName)
            }

            if hasInternet,
               (!previousState.isConnected || previousState.isPersonalHotspot) {
                return NetworkStatusEvent(kind: .wifiConnected, networkName: networkName)
            }

            return nil
        }
    }

    private nonisolated static func probeInternetConnection() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: canOpenInternetSocket())
            }
        }
    }

    private nonisolated static func canOpenInternetSocket() -> Bool {
        var hints = addrinfo()
        hints.ai_flags = AI_ADDRCONFIG
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var addresses: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo("www.apple.com", "443", &hints, &addresses) == 0,
              let firstAddress = addresses else {
            return false
        }
        defer { freeaddrinfo(firstAddress) }

        let timeoutNanoseconds: UInt64 = 3_000_000_000
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        var address: UnsafeMutablePointer<addrinfo>? = firstAddress

        while let currentAddress = address {
            let descriptor = socket(
                currentAddress.pointee.ai_family,
                currentAddress.pointee.ai_socktype,
                currentAddress.pointee.ai_protocol
            )

            if descriptor >= 0 {
                let existingFlags = fcntl(descriptor, F_GETFL, 0)
                let didEnableNonBlocking =
                    existingFlags >= 0 &&
                    fcntl(descriptor, F_SETFL, existingFlags | O_NONBLOCK) == 0

                if didEnableNonBlocking {
                    let result = connect(
                        descriptor,
                        currentAddress.pointee.ai_addr,
                        currentAddress.pointee.ai_addrlen
                    )

                    if result == 0 ||
                        (result == -1 && errno == EINPROGRESS &&
                         socketBecomesWritable(descriptor, before: deadline)) {
                        close(descriptor)
                        return true
                    }
                }

                close(descriptor)
            }

            guard DispatchTime.now().uptimeNanoseconds < deadline else {
                return false
            }
            address = currentAddress.pointee.ai_next
        }

        return false
    }

    private nonisolated static func socketBecomesWritable(
        _ descriptor: Int32,
        before deadline: UInt64
    ) -> Bool {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadline else { return false }

        let remainingMilliseconds = max(1, (deadline - now) / 1_000_000)
        var pollDescriptor = pollfd(
            fd: descriptor,
            events: Int16(POLLOUT),
            revents: 0
        )

        let pollResult = poll(
            &pollDescriptor,
            1,
            Int32(min(remainingMilliseconds, UInt64(Int32.max)))
        )
        guard pollResult > 0 else { return false }

        var socketError: Int32 = 0
        var socketErrorLength = socklen_t(MemoryLayout.size(ofValue: socketError))
        guard getsockopt(
            descriptor,
            SOL_SOCKET,
            SO_ERROR,
            &socketError,
            &socketErrorLength
        ) == 0 else {
            return false
        }

        return socketError == 0
    }

    nonisolated private func requestRefreshFromWiFiEvent() {
        Task { @MainActor [weak self] in
            self?.scheduleRefresh()
        }
    }
}

private extension NetworkConnectionState {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isConnectedWithoutInternet: Bool {
        if case let .connected(_, _, hasInternet) = self {
            return !hasInternet
        }
        return false
    }

    var isPersonalHotspot: Bool {
        if case let .connected(_, isPersonalHotspot, _) = self {
            return isPersonalHotspot
        }
        return false
    }

    func matchesConnected(isPersonalHotspot: Bool, hasInternet: Bool) -> Bool {
        guard case let .connected(_, currentHotspot, currentInternet) = self else {
            return false
        }

        return currentHotspot == isPersonalHotspot && currentInternet == hasInternet
    }
}

extension NetworkStatusManager: CWEventDelegate {
    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        requestRefreshFromWiFiEvent()
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        requestRefreshFromWiFiEvent()
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        requestRefreshFromWiFiEvent()
    }

    nonisolated func modeDidChangeForWiFiInterface(withName interfaceName: String) {
        requestRefreshFromWiFiEvent()
    }
}

// The project links private media frameworks that contain another framework named
// Network. Loading the public Network.framework explicitly avoids that name collision.
private final class SystemNetworkPathMonitor: @unchecked Sendable {
    private typealias NetworkObject = UnsafeMutableRawPointer
    private typealias UpdateBlock = @convention(block) (NetworkObject) -> Void
    private typealias CreateFunction = @convention(c) () -> NetworkObject?
    private typealias SetUpdateHandlerFunction = @convention(c) (
        NetworkObject,
        UpdateBlock
    ) -> Void
    private typealias SetQueueFunction = @convention(c) (
        NetworkObject,
        NetworkObject
    ) -> Void
    private typealias MonitorActionFunction = @convention(c) (NetworkObject) -> Void
    private typealias PathStatusFunction = @convention(c) (NetworkObject) -> UInt32
    private typealias PathBooleanFunction = @convention(c) (NetworkObject) -> Bool
    private typealias PathUsesInterfaceFunction = @convention(c) (
        NetworkObject,
        UInt32
    ) -> Bool

    private let libraryHandle: NetworkObject
    private let monitor: NetworkObject
    private let setUpdateHandler: SetUpdateHandlerFunction
    private let setQueue: SetQueueFunction
    private let startMonitor: MonitorActionFunction
    private let cancelMonitor: MonitorActionFunction
    private let pathStatus: PathStatusFunction
    private let pathIsExpensive: PathBooleanFunction
    private let pathUsesInterface: PathUsesInterfaceFunction
    private var updateBlock: UpdateBlock?
    private var isStarted = false

    init?() {
        let frameworkPath = "/System/Library/Frameworks/Network.framework/Network"
        guard let libraryHandle = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL) else {
            return nil
        }

        guard let create: CreateFunction = Self.loadSymbol(
                "nw_path_monitor_create",
                from: libraryHandle
              ),
              let setUpdateHandler: SetUpdateHandlerFunction = Self.loadSymbol(
                "nw_path_monitor_set_update_handler",
                from: libraryHandle
              ),
              let setQueue: SetQueueFunction = Self.loadSymbol(
                "nw_path_monitor_set_queue",
                from: libraryHandle
              ),
              let startMonitor: MonitorActionFunction = Self.loadSymbol(
                "nw_path_monitor_start",
                from: libraryHandle
              ),
              let cancelMonitor: MonitorActionFunction = Self.loadSymbol(
                "nw_path_monitor_cancel",
                from: libraryHandle
              ),
              let pathStatus: PathStatusFunction = Self.loadSymbol(
                "nw_path_get_status",
                from: libraryHandle
              ),
              let pathIsExpensive: PathBooleanFunction = Self.loadSymbol(
                "nw_path_is_expensive",
                from: libraryHandle
              ),
              let pathUsesInterface: PathUsesInterfaceFunction = Self.loadSymbol(
                "nw_path_uses_interface_type",
                from: libraryHandle
              ),
              let monitor = create() else {
            dlclose(libraryHandle)
            return nil
        }

        self.libraryHandle = libraryHandle
        self.monitor = monitor
        self.setUpdateHandler = setUpdateHandler
        self.setQueue = setQueue
        self.startMonitor = startMonitor
        self.cancelMonitor = cancelMonitor
        self.pathStatus = pathStatus
        self.pathIsExpensive = pathIsExpensive
        self.pathUsesInterface = pathUsesInterface
    }

    deinit {
        cancel()
        Unmanaged<AnyObject>.fromOpaque(monitor).release()
    }

    func start(
        queue: DispatchQueue,
        handler: @escaping @Sendable (NetworkPathSnapshot) -> Void
    ) {
        guard !isStarted else { return }
        isStarted = true

        let pathStatus = pathStatus
        let pathUsesInterface = pathUsesInterface
        let pathIsExpensive = pathIsExpensive

        let updateBlock: UpdateBlock = { path in
            handler(NetworkPathSnapshot(
                isSatisfied: pathStatus(path) == 1,
                usesWiFi: pathUsesInterface(path, 1),
                isExpensive: pathIsExpensive(path)
            ))
        }
        self.updateBlock = updateBlock

        setUpdateHandler(monitor, updateBlock)
        setQueue(monitor, Unmanaged.passUnretained(queue).toOpaque())
        startMonitor(monitor)
    }

    func cancel() {
        guard isStarted else { return }
        isStarted = false
        cancelMonitor(monitor)
        updateBlock = nil
    }

    private static func loadSymbol<T>(
        _ name: String,
        from handle: NetworkObject
    ) -> T? {
        guard let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
