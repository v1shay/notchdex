import AppKit
import ApplicationServices

final class GestureController {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var retryTimer: Timer?
    private let isOpen: () -> Bool
    private let toggle: () -> Void
    private let close: () -> Void
    private let typeText: (String) -> Void
    private let beginDictation: () -> Void
    private let endDictation: () -> Void

    private var shiftDown = false
    private var shiftHold: DispatchWorkItem?
    private var lastShiftTap: TimeInterval = 0
    private var suppressNextShiftRelease = false
    private var xDown = false
    private var xHold: DispatchWorkItem?
    private var dictating = false
    private var pendingX = "x"

    init(
        isOpen: @escaping () -> Bool,
        toggle: @escaping () -> Void,
        close: @escaping () -> Void,
        typeText: @escaping (String) -> Void,
        beginDictation: @escaping () -> Void,
        endDictation: @escaping () -> Void
    ) {
        self.isOpen = isOpen
        self.toggle = toggle
        self.close = close
        self.typeText = typeText
        self.beginDictation = beginDictation
        self.endDictation = endDictation
        requestAccessibility()
        installTap()
        installFallbackMonitors()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.tap == nil else { return }
            self.installTap()
        }
    }

    deinit { stop() }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        retryTimer?.invalidate()
        retryTimer = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func installTap() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = 1 << CGEventType.flagsChanged.rawValue
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<GestureController>.fromOpaque(refcon).takeUnretainedValue()
            controller.handleTap(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func installFallbackMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleShiftEvent(keyCode: event.keyCode, flags: event.modifierFlags)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged {
                self.handleShiftEvent(keyCode: event.keyCode, flags: event.modifierFlags)
                return event
            }
            guard self.isOpen(), event.keyCode == 7 else { return event }
            if event.type == .keyDown {
                if !event.isARepeat { self.handleXDown(uppercase: event.modifierFlags.contains(.shift)) }
                return nil
            }
            if event.type == .keyUp {
                self.handleXUp()
                return nil
            }
            return event
        }
    }

    private func handleTap(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags: NSEvent.ModifierFlags = event.flags.contains(.maskShift) ? [.shift] : []
        handleShiftEvent(keyCode: keyCode, flags: flags)
    }

    private func handleShiftEvent(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        guard keyCode == 56 || keyCode == 60 else { return }
        handleShift(down: flags.contains(.shift))
    }

    private func handleShift(down: Bool) {
        guard down != shiftDown else { return }
        shiftDown = down
        if down {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.shiftDown, !self.isOpen() else { return }
                self.suppressNextShiftRelease = true
                self.toggle()
                self.lastShiftTap = 0
            }
            shiftHold = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
        } else {
            shiftHold?.cancel()
            shiftHold = nil
            if suppressNextShiftRelease {
                suppressNextShiftRelease = false
                return
            }
            let now = ProcessInfo.processInfo.systemUptime
            if isOpen(), now - lastShiftTap < 0.38 {
                lastShiftTap = 0
                close()
            } else {
                lastShiftTap = now
            }
        }
    }

    private func handleXDown(uppercase: Bool) {
        guard !xDown else { return }
        xDown = true
        pendingX = uppercase ? "X" : "x"
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.xDown else { return }
            self.dictating = true
            self.beginDictation()
        }
        xHold = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func handleXUp() {
        guard xDown else { return }
        xDown = false
        xHold?.cancel()
        xHold = nil
        if dictating {
            dictating = false
            endDictation()
        } else {
            typeText(pendingX)
        }
    }
}
