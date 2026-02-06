import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController {
    static let shared = BreakOverlayController()

    private var windowsByScreenNumber: [Int: OverlayWindow] = [:]
    private var currentKind: OverlayKind?
    private var currentOnSnooze10: (() -> Void)?
    private var screenObserver: NSObjectProtocol?

    func presentStandBreak(
        minDurationSeconds: Int,
        maxDurationSeconds: Int = 5 * 60,
        onSnooze10: (() -> Void)? = nil
    ) {
        presentOverlay(
            kind: .stand(minDurationSeconds: minDurationSeconds, maxDurationSeconds: maxDurationSeconds),
            onSnooze10: onSnooze10
        )
    }

    func presentEyesRest(minDurationSeconds: Int, maxDurationSeconds: Int = 5 * 60) {
        presentOverlay(
            kind: .eyes(minDurationSeconds: minDurationSeconds, maxDurationSeconds: maxDurationSeconds),
            onSnooze10: nil
        )
    }

    private func presentOverlay(kind: OverlayKind, onSnooze10: (() -> Void)?) {
        closeAll()

        currentKind = kind
        currentOnSnooze10 = onSnooze10
        rebuildWindowsForCurrentScreens()
        startObservingScreenChanges()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeAll() {
        stopObservingScreenChanges()
        for (_, w) in windowsByScreenNumber {
            w.orderOut(nil)
            w.close()
        }
        windowsByScreenNumber.removeAll()
        currentKind = nil
        currentOnSnooze10 = nil
    }

    private func startObservingScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.rebuildWindowsForCurrentScreens()
            }
        }
    }

    private func stopObservingScreenChanges() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    private func rebuildWindowsForCurrentScreens() {
        guard let kind = currentKind else { return }

        for (_, w) in windowsByScreenNumber {
            w.orderOut(nil)
            w.close()
        }
        windowsByScreenNumber.removeAll()

        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let key = screen.screenNumber ?? (10_000 + index)
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.setFrame(screen.frame, display: true)

            let onSnooze10 = currentOnSnooze10
            let rootView = BreakOverlayView(kind: kind) { [weak self] action in
                guard let self else { return }
                switch action {
                case .snooze10:
                    onSnooze10?()
                    self.closeAll()
                case .done:
                    self.closeAll()
                }
            }

            window.contentView = NSHostingView(rootView: rootView)
            windowsByScreenNumber[key] = window
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private extension NSScreen {
    var screenNumber: Int? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue
    }
}

private enum OverlayKind: Equatable {
    case stand(minDurationSeconds: Int, maxDurationSeconds: Int)
    case eyes(minDurationSeconds: Int, maxDurationSeconds: Int)

    var type: ReminderType {
        switch self {
        case .stand:
            return .stand
        case .eyes:
            return .eyes
        }
    }

    var minDurationSeconds: Int {
        switch self {
        case .stand(let s, _), .eyes(let s, _):
            return s
        }
    }

    var maxDurationSeconds: Int {
        switch self {
        case .stand(_, let s), .eyes(_, let s):
            return s
        }
    }
}

private enum OverlayAction {
    case snooze10
    case done
}

private struct BreakOverlayView: View {
    let kind: OverlayKind
    let onAction: (OverlayAction) -> Void

    @State private var now = Date()
    @State private var didAutoClose = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            background
            content
        }
        .onAppear {
            startReference = Date().timeIntervalSinceReferenceDate
        }
        .onReceive(timer) { t in
            now = t
            if !didAutoClose, elapsedSeconds >= kind.maxDurationSeconds {
                didAutoClose = true
                onAction(.done)
            }
        }
    }

    private var background: some View {
        switch kind {
        case .stand:
            return AnyView(
                LinearGradient(
                    colors: [Color.black.opacity(0.78), Color.black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .eyes:
            return AnyView(Color.black)
        }
    }

    private var content: some View {
        let remaining = max(0, kind.minDurationSeconds - elapsedSeconds)
        let remainingMax = max(0, kind.maxDurationSeconds - elapsedSeconds)
        return VStack(spacing: 18) {
            Spacer()

            Image(systemName: headerSymbol)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(headerTint)

            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)

            Text(subtitle(remainingSeconds: remaining, remainingMaxSeconds: remainingMax))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                if kind.type == .stand {
                    Button {
                        onAction(.snooze10)
                    } label: {
                        label("稍后 10 分钟", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                    .disabled(remaining > 0)
                    .opacity(remaining > 0 ? 0.55 : 1)
                }

                Button {
                    onAction(.done)
                } label: {
                    label(doneTitle, systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.plain)
                .opacity(remaining > 0 ? 0.55 : 1)
                .disabled(remaining > 0)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .controlSize(.large)
            .padding(.top, 8)

            Spacer()
        }
        .padding(32)
    }

    private func label(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(headerTint.opacity(0.92))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var elapsedSeconds: Int {
        Int(now.timeIntervalSinceReferenceDate) - Int(startReference)
    }

    @State private var startReference: TimeInterval = Date().timeIntervalSinceReferenceDate

    private var headerSymbol: String {
        switch kind {
        case .stand:
            return "figure.stand"
        case .eyes:
            return "eye.slash.fill"
        }
    }

    private var headerTint: Color {
        switch kind {
        case .stand:
            return Color(red: 0.35, green: 0.86, blue: 0.73)
        case .eyes:
            return Color(red: 0.52, green: 0.62, blue: 1.0)
        }
    }

    private var title: String {
        switch kind {
        case .stand:
            return "站起来走动"
        case .eyes:
            return "闭眼休息"
        }
    }

    private func subtitle(remainingSeconds: Int, remainingMaxSeconds: Int) -> String {
        switch kind {
        case .stand:
            if remainingSeconds > 0 {
                return "强制中断一下：站立并活动至少 2 分钟。\n剩余 \(remainingSeconds) 秒"
            }
            if remainingMaxSeconds > 0 {
                return "做得好！你可以继续工作了。\n如无操作，将在 \(remainingMaxSeconds) 秒后自动结束。"
            }
            return "本次站立结束。"
        case .eyes:
            if remainingSeconds > 0 {
                return "屏幕用眼休息，减少干涩与疲劳。\n剩余 \(remainingSeconds) 秒"
            }
            if remainingMaxSeconds > 0 {
                return "休息完成。点击结束休息返回。\n如无操作，将在 \(remainingMaxSeconds) 秒后自动结束。"
            }
            return "本次休息结束。"
        }
    }

    private var doneTitle: String {
        switch kind {
        case .stand:
            return "我已站立 2 分钟"
        case .eyes:
            return "结束休息"
        }
    }
}
