//
//  LoginView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct LoginView: View {
    var body: some View {
        #if os(macOS)
        LoginView_macOS()
        #elseif os(iOS)
        LoginView_iOS()
        #else
        // Fallback for other platforms
        Text("Login - Platform not supported")
        #endif
    }
}

#Preview {
    #if os(macOS)
    LoginView_macOS()
    #else
    LoginView_iOS()
    #endif
}
