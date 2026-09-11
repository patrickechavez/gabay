//
//  NotificationsView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Second screen of the Settings tab.
struct NotificationsView: View {

    @Environment(Router<SettingsRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.blockedUsers)
            } label: {
                Text("Blocked Users", comment: "Button that opens the blocked users screen")
            }

            // The back arrow already does this; use code when leaving after an action.
            Button {
                router.pop()
            } label: {
                Text("Back", comment: "Button that returns to the previous screen")
            }
        }
        .navigationTitle(Text("Notifications", comment: "Title of the notification settings screen"))
    }
}
