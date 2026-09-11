//
//  SettingsView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// First screen of the Settings tab.
struct SettingsView: View {

    @Environment(Router<SettingsRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.notifications)
            } label: {
                Label {
                    Text("Notifications", comment: "Row that opens the notification settings screen")
                } icon: {
                    Image(systemName: "bell")
                }
            }
        }
        .navigationTitle(Text("Settings", comment: "Title of the settings screen"))
    }
}
