//
//  ForgotPasswordView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    var body: some View {
        #if os(macOS)
        ForgotPasswordView_macOS()
        #elseif os(iOS)
        ForgotPasswordView_iOS()
        #else
        // Fallback for other platforms
        Text("Forgot Password - Platform not supported")
        #endif
    }
}

#Preview {
    #if os(macOS)
    ForgotPasswordView_macOS()
    #else
    ForgotPasswordView_iOS()
    #endif
}
