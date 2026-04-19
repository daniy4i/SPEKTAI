//
//  AccountSettingsView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        #if os(macOS)
        AccountSettingsView_macOS()
        #elseif os(iOS)
        AccountSettingsView_iOS()
        #else
        // Fallback for other platforms
        Text("Account Settings - Platform not supported")
        #endif
    }
}

#Preview {
    AccountSettingsView()
}
