import Cocoa
import SwiftUI

@MainActor
final class FloatingHUDWindow: NSObject {
    static let shared = FloatingHUDWindow()
    private(set) var panel: NSPanel?
    let viewModel = FloatingHUDViewModel()
    private var presentationVersion = 0
    private var hostingView: NSHostingView<FloatingHUDView>?

    private override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true

        let contentView = FloatingHUDView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: contentView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingView = hosting
        panel.contentView = hosting

        self.panel = panel
    }

    func update(state: HUDState) {
        guard let panel = panel else { return }

        // Any new content invalidates a delayed hide from the previous state.
        presentationVersion += 1
        let isLevelUpdateOnly: Bool
        switch (viewModel.state, state) {
        case (.listening(_, let oldMode), .listening(_, let newMode)):
            isLevelUpdateOnly = oldMode == newMode && panel.isVisible
        default:
            isLevelUpdateOnly = false
        }
        let startsListening: Bool
        if case .listening = state { startsListening = true } else { startsListening = false }

        if !panel.isVisible || startsListening && !isListeningState {
            // Flush the new content before orderFront, without animating the old result.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                viewModel.state = state
                hostingView?.rootView = FloatingHUDView(viewModel: viewModel)
                hostingView?.layoutSubtreeIfNeeded()
                hostingView?.displayIfNeeded()
            }
        } else if isLevelUpdateOnly {
            viewModel.state = state
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                viewModel.state = state
            }
        }

        if !isLevelUpdateOnly, let hosting = hostingView {
            panel.layoutIfNeeded()
            let fittingSize = hosting.fittingSize
            if fittingSize.width > 50 && fittingSize.height > 20 {
                panel.setContentSize(fittingSize)
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    panel.setFrameOrigin(NSPoint(
                        x: screenFrame.midX - fittingSize.width / 2,
                        y: screenFrame.minY + 60
                    ))
                }
            }
        }

        if !panel.isVisible {
            panel.alphaValue = 0.0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 1.0
            }
        }
    }

    private var isListeningState: Bool {
        if case .listening = viewModel.state { return true }
        return false
    }

    func hide(delay: TimeInterval = 0.0) {
        let version = presentationVersion
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.presentationVersion == version else { return }
            // Hide before resetting: SwiftUI must never render the previous result on reopen.
            self.panel?.orderOut(nil)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.viewModel.state = .listening(level: 0, mode: .dictation)
            }
        }
    }
}
