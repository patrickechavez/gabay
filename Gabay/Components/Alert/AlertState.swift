//
//  AlertState.swift
//  Gabay
//

import SwiftUI

// An alert a view model can raise without knowing anything about SwiftUI's
// presentation machinery. Setting it to nil dismisses.
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    var message: String?
    var buttons: [AlertButton]

    // One button that only dismisses. Covers both a confirmation and a
    // failure, which is why it is not called `error`.
    static func notice(_ title: String, _ message: String? = nil) -> AlertState {
        AlertState(
            title: title,
            message: message,
            buttons: [AlertButton(title: String(localized: "OK", comment: "Dismisses an alert"))]
        )
    }
}

struct AlertButton: Identifiable {
    let id = UUID()
    let title: String
    var role: ButtonRole?
    var action: () -> Void = {}
}

extension View {

    func appAlert(_ state: Binding<AlertState?>) -> some View {
        alert(
            state.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { state.wrappedValue != nil },
                set: { if !$0 { state.wrappedValue = nil } }
            ),
            presenting: state.wrappedValue
        ) { alert in
            ForEach(alert.buttons) { button in
                Button(button.title, role: button.role, action: button.action)
            }
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }
}
