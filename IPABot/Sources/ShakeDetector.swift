import SwiftUI
import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// No AppDelegate in this app's SwiftUI lifecycle, so shake detection goes
/// through a bare invisible UIViewController that becomes first responder and
/// overrides motionEnded — the standard no-AppDelegate trick.
private struct ShakeDetectingView: UIViewControllerRepresentable {
    final class ShakeVC: UIViewController {
        override var canBecomeFirstResponder: Bool { true }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                NotificationCenter.default.post(name: .deviceDidShake, object: nil)
            }
        }
    }

    func makeUIViewController(context: Context) -> ShakeVC { ShakeVC() }
    func updateUIViewController(_ uiViewController: ShakeVC, context: Context) {}
}

struct ShakeDetector: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content
            .background(ShakeDetectingView().frame(width: 0, height: 0))
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in action() }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetector(action: action))
    }
}
