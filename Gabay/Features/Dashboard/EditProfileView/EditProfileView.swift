//
//  EditProfileView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Second screen of the Profile tab.
struct EditProfileView: View {

    @Environment(Router<ProfileRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.changePassword)
            } label: {
                Text("Change Password", comment: "Button that opens the change password screen")
            }

            // The back arrow already does this; use code when leaving after an action.
            Button {
                router.pop()
            } label: {
                Text("Back", comment: "Button that returns to the previous screen")
            }
        }
        .navigationTitle(Text("Edit Profile", comment: "Title of the edit profile screen"))
    }
}
