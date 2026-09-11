//
//  ChangePasswordView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Third screen of the Profile tab.
struct ChangePasswordView: View {

    @Environment(Router<ProfileRoute>.self) private var router

    var body: some View {
        List {
            // Clears every screen in this tab only; other tabs stay put.
            Button {
                router.popToRoot()
            } label: {
                Text("Back to Root", comment: "Button that returns to the first screen of the tab")
            }
        }
        .navigationTitle(Text("Change Password", comment: "Title of the change password screen"))
    }
}
