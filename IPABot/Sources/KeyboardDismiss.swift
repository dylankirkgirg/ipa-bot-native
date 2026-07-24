import SwiftUI
import UIKit

/// SwiftUI's .onSubmit doesn't dismiss the keyboard by itself, and .decimalPad
/// / .numberPad have no Return key at all — several fields (search, iOS
/// version) had no way to dismiss the keyboard short of force-quitting.
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
