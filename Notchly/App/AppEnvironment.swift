//
//  AppEnvironment.swift
//  Notchly
//
//  Created by user on 03.05.2026.
//

import Foundation
import Combine
import Darwin
import notify
import ObjectiveC.runtime
import Sparkle

@MainActor
final class AppEnvironment {
    let musicManager = MusicManager()
    let settingsManager = SettingsManager()
    let focusManager = FocusManager()
    let lockScreenOverlayModel = LockScreenOverlayModel()

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    lazy var batteryManager = BatteryManager(musicManager: musicManager)

    lazy var dynamicManager = DynamicManager(
        batteryManager: batteryManager,
        musicManager: musicManager,
        settingsManager: settingsManager
    )

    lazy var settingsWindow = SettingsWindow(
        settingsManager: settingsManager
    )
}

// MARK: - Focus Manager

@MainActor
final class FocusManager: ObservableObject {
    @Published private(set) var focusEventID = 0
    @Published private(set) var focusEventIsActive = false

    private let focusNotificationNames = [
        "_NSDoNotDisturbEnabledNotification",
        "_NSDoNotDisturbDisabledNotification",
        "com.apple.notificationcenterui.dndprefs_changed",
        "com.apple.ncprefs.settings.changed",
        "com.apple.ncprefs.settings.accountschanged",
        "com.apple.focus.statusChanged",
        "com.apple.donotdisturb.statusChanged",
        "com.apple.menuextra.focusmode",
        "com.apple.controlcenter.focusmodes",
        "com.apple.notificationcenter.dnd.state.changed",
        "com.apple.focus.assertion.state.changed",
        "com.apple.focus.status.changed"
    ]

    private var distributedObservers: [FocusDistributedNotificationRelay] = []
    private var darwinNotifyTokens: [Int32] = []

    private var dndStateService: AnyObject?
    private var dndStateListener: DNDStateUpdateListener?
    private var dndStateServiceClass: AnyClass?

    private var refreshTask: Task<Void, Never>?

    private var isRunning = false
    private var isFocusActive = false
    private var lastPublishedEvent: (isActive: Bool, timestamp: TimeInterval)?
    private var lastKnownQueriedState: Bool?

    func start() {
        guard !isRunning else { return }

        isRunning = true

        installDNDStateServiceListener()
        installDistributedNotificationObservers()
        installDarwinNotificationObservers()

        refreshFocusState(announceChanges: false)
    }

    func stop() {
        isRunning = false

        refreshTask?.cancel()
        refreshTask = nil

        removeDNDStateServiceListener()

        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.forEach { distributedCenter.removeObserver($0) }
        distributedObservers.removeAll()

        darwinNotifyTokens.forEach { notify_cancel($0) }
        darwinNotifyTokens.removeAll()
    }

    // MARK: - Notification observers

    private func installDistributedNotificationObservers() {
        let center = DistributedNotificationCenter.default()

        distributedObservers = focusNotificationNames.map { name in
            let relay = FocusDistributedNotificationRelay(name: name) { [weak self] name in
                Task { @MainActor [weak self] in
                    self?.handleFocusNotification(named: name)
                }
            }

            center.addObserver(
                relay,
                selector: #selector(FocusDistributedNotificationRelay.receive(_:)),
                name: NSNotification.Name(name),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )

            return relay
        }
    }

    private func installDarwinNotificationObservers() {
        for name in focusNotificationNames {
            var token: Int32 = 0

            let status = notify_register_dispatch(
                name,
                &token,
                DispatchQueue.main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleFocusNotification(named: name)
                }
            }

            if status == NOTIFY_STATUS_OK {
                darwinNotifyTokens.append(token)
            }
        }
    }

    private func handleFocusNotification(named name: String) {
        guard isRunning else { return }

        switch name {
        case "_NSDoNotDisturbEnabledNotification":
            refreshTask?.cancel()
            refreshTask = nil
            setFocusState(true, announceChanges: true)

        case "_NSDoNotDisturbDisabledNotification":
            refreshTask?.cancel()
            refreshTask = nil
            setFocusState(false, announceChanges: true)

        default:
            let didChange = refreshFocusState(announceChanges: true)
            scheduleFocusRefreshBurst(didChangeImmediately: didChange)
        }
    }

    private func scheduleFocusRefreshBurst(didChangeImmediately: Bool) {
        refreshTask?.cancel()

        let delays: [Duration] = didChangeImmediately
            ? [.milliseconds(180), .milliseconds(500)]
            : [.milliseconds(60), .milliseconds(160), .milliseconds(320), .milliseconds(700)]

        refreshTask = Task { [weak self] in
            for delay in delays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    _ = self?.refreshFocusState(announceChanges: true)
                }
            }

            await MainActor.run { [weak self] in
                self?.refreshTask = nil
            }
        }
    }

    // MARK: - State

    @discardableResult
    private func refreshFocusState(announceChanges: Bool) -> Bool {
        guard isRunning else { return false }

        if let queriedState = queryDNDStateService() {
            lastKnownQueriedState = queriedState
            return setFocusState(queriedState, announceChanges: announceChanges)
        }

        if let lastKnownQueriedState {
            return setFocusState(lastKnownQueriedState, announceChanges: announceChanges)
        }

        return false
    }

    @discardableResult
    private func setFocusState(_ isActive: Bool, announceChanges: Bool) -> Bool {
        let didChange = isFocusActive != isActive

        if didChange {
            isFocusActive = isActive
        }

        if announceChanges && didChange {
            publishFocusEvent(isActive)
        }

        return didChange
    }

    private func publishFocusEvent(_ isActive: Bool) {
        let now = Date.timeIntervalSinceReferenceDate

        if let lastPublishedEvent,
           lastPublishedEvent.isActive == isActive,
           now - lastPublishedEvent.timestamp < 0.35 {
            return
        }

        lastPublishedEvent = (isActive, now)
        focusEventIsActive = isActive
        focusEventID += 1
    }

    // MARK: - DND private API

    private var dndClientIdentifier: String {
        Bundle.main.bundleIdentifier ?? "xyz.notchly.Notchly"
    }

    private func installDNDStateServiceListener() {
        guard dndStateService == nil else { return }

        guard dlopen(
            "/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb",
            RTLD_NOW
        ) != nil else { return }

        guard let serviceClass = NSClassFromString("DNDStateService") else { return }

        guard let service = makeDNDStateService(serviceClass: serviceClass) else { return }

        let listener = DNDStateUpdateListener(
            clientIdentifier: dndClientIdentifier
        ) { [weak self] isActive in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }

                self.refreshTask?.cancel()
                self.refreshTask = nil

                self.lastKnownQueriedState = isActive
                self.setFocusState(isActive, announceChanges: true)
            }
        }

        var error: NSError?
        let added = addDNDStateListener(
            listener,
            to: service,
            serviceClass: serviceClass,
            error: &error
        )

        guard added else { return }

        dndStateService = service
        dndStateListener = listener
        dndStateServiceClass = serviceClass

        if let currentState = queryDNDStateService() {
            lastKnownQueriedState = currentState
            setFocusState(currentState, announceChanges: false)
        }
    }

    private func removeDNDStateServiceListener() {
        if let service = dndStateService,
           let listener = dndStateListener,
           let serviceClass = dndStateServiceClass {
            var error: NSError?

            _ = removeDNDStateListener(
                listener,
                from: service,
                serviceClass: serviceClass,
                error: &error
            )
        }

        dndStateService = nil
        dndStateListener = nil
        dndStateServiceClass = nil
    }

    private func makeDNDStateService(serviceClass: AnyClass) -> AnyObject? {
        let selector = NSSelectorFromString("_initWithClientIdentifier:")

        guard let instance = class_createInstance(serviceClass, 0) as AnyObject? else {
            return nil
        }

        guard let implementation = class_getMethodImplementation(serviceClass, selector) else {
            return nil
        }

        typealias InitFunction = @convention(c) (
            AnyObject,
            Selector,
            NSString
        ) -> AnyObject?

        let initialize = unsafeBitCast(implementation, to: InitFunction.self)

        return initialize(instance, selector, dndClientIdentifier as NSString)
    }

    private func addDNDStateListener(
        _ listener: DNDStateUpdateListener,
        to service: AnyObject,
        serviceClass: AnyClass,
        error: AutoreleasingUnsafeMutablePointer<NSError?>?
    ) -> Bool {
        let selector = NSSelectorFromString("addStateUpdateListener:error:")

        guard let implementation = class_getMethodImplementation(serviceClass, selector) else {
            return false
        }

        typealias AddFunction = @convention(c) (
            AnyObject,
            Selector,
            AnyObject,
            AutoreleasingUnsafeMutablePointer<NSError?>?
        ) -> Bool

        let add = unsafeBitCast(implementation, to: AddFunction.self)

        return add(service, selector, listener, error)
    }

    private func removeDNDStateListener(
        _ listener: DNDStateUpdateListener,
        from service: AnyObject,
        serviceClass: AnyClass,
        error: AutoreleasingUnsafeMutablePointer<NSError?>?
    ) -> Bool {
        let selector = NSSelectorFromString("removeStateUpdateListener:error:")

        guard let implementation = class_getMethodImplementation(serviceClass, selector) else {
            return false
        }

        typealias RemoveFunction = @convention(c) (
            AnyObject,
            Selector,
            AnyObject,
            AutoreleasingUnsafeMutablePointer<NSError?>?
        ) -> Bool

        let remove = unsafeBitCast(implementation, to: RemoveFunction.self)

        return remove(service, selector, listener, error)
    }

    private func queryDNDStateService() -> Bool? {
        guard let service = dndStateService,
              let serviceClass = dndStateServiceClass else {
            return nil
        }

        let selector = NSSelectorFromString("queryCurrentStateWithError:")

        guard let implementation = class_getMethodImplementation(serviceClass, selector) else {
            return nil
        }

        typealias QueryFunction = @convention(c) (
            AnyObject,
            Selector,
            AutoreleasingUnsafeMutablePointer<NSError?>?
        ) -> AnyObject?

        var error: NSError?
        let query = unsafeBitCast(implementation, to: QueryFunction.self)

        guard let state = query(service, selector, &error) else { return nil }

        return DNDStateUpdateListener.isFocusActive(in: state)
    }
}

private final class FocusDistributedNotificationRelay: NSObject {
    private let name: String
    private let handler: (String) -> Void

    init(name: String, handler: @escaping (String) -> Void) {
        self.name = name
        self.handler = handler
        super.init()
    }

    @objc func receive(_ notification: Notification) {
        handler(name)
    }
}

// MARK: - DND State Update Listener

private final class DNDStateUpdateListener: NSObject {
    private let identifier: String
    private let onUpdate: (Bool) -> Void

    init(clientIdentifier: String, onUpdate: @escaping (Bool) -> Void) {
        self.identifier = clientIdentifier
        self.onUpdate = onUpdate
        super.init()
    }

    @objc var clientIdentifier: String {
        identifier
    }

    @objc(remoteService:didReceiveDoNotDisturbStateUpdate:)
    func remoteService(
        _ service: AnyObject,
        didReceiveDoNotDisturbStateUpdate update: AnyObject
    ) {
        handleUpdate(update)
    }

    @objc(stateService:didReceiveDoNotDisturbStateUpdate:)
    func stateService(
        _ service: AnyObject,
        didReceiveDoNotDisturbStateUpdate update: AnyObject
    ) {
        handleUpdate(update)
    }

    @objc(remoteService:didReceiveStateUpdate:)
    func remoteService(
        _ service: AnyObject,
        didReceiveStateUpdate update: AnyObject
    ) {
        handleUpdate(update)
    }

    private func handleUpdate(_ update: AnyObject) {
        if let updateObject = update as? NSObject,
           let state = updateObject.safeObjectValue(forKey: "state"),
           let isActive = Self.isFocusActive(in: state) {
            onUpdate(isActive)
            return
        }

        if let isActive = Self.isFocusActive(in: update) {
            onUpdate(isActive)
        }
    }

    static func isFocusActive(in state: AnyObject) -> Bool? {
        guard let object = state as? NSObject else {
            return nil
        }

        let boolKeys = [
            "isActive",
            "active",
            "enabled",
            "isEnabled"
        ]

        for key in boolKeys {
            if let boolValue = object.boolValue(forSelectorName: key) ?? object.safeBoolValue(forKey: key) {
                return boolValue
            }
        }

        let objectKeys = [
            "activeModeIdentifier",
            "activeMode",
            "modeIdentifier",
            "currentMode"
        ]

        for key in objectKeys {
            guard let value = object.objectValue(forSelectorName: key) ?? object.safeObjectValue(forKey: key) else {
                continue
            }

            if let stringValue = value as? String {
                return !stringValue.isEmpty
            }

            return true
        }

        return nil
    }
}

// MARK: - Objective-C Runtime Access

private extension NSObject {
    func objectValue(forSelectorName selectorName: String) -> AnyObject? {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else { return nil }
        guard let implementation = class_getMethodImplementation(type(of: self), selector) else { return nil }

        typealias ObjectGetter = @convention(c) (AnyObject, Selector) -> AnyObject?
        let getter = unsafeBitCast(implementation, to: ObjectGetter.self)

        return getter(self, selector)
    }

    func boolValue(forSelectorName selectorName: String) -> Bool? {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector) else { return nil }
        guard let implementation = class_getMethodImplementation(type(of: self), selector) else { return nil }

        typealias BoolGetter = @convention(c) (AnyObject, Selector) -> Bool
        let getter = unsafeBitCast(implementation, to: BoolGetter.self)

        return getter(self, selector)
    }

    func safeObjectValue(forKey key: String) -> AnyObject? {
        ObjCRuntimeSafety.value(forKey: key, from: self) as AnyObject?
    }

    func safeBoolValue(forKey key: String) -> Bool? {
        if let boolValue = ObjCRuntimeSafety.value(forKey: key, from: self) as? Bool {
            return boolValue
        }

        if let numberValue = ObjCRuntimeSafety.value(forKey: key, from: self) as? NSNumber {
            return numberValue.boolValue
        }

        return nil
    }
}
