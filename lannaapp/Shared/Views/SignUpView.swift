//
//  SignUpView.swift
//  lannaapp
//
//  Created by Kareem Duarte on 8/31/25.
//

import SwiftUI

struct SignUpView: View {
    var body: some View {
        #if os(macOS)
        SignUpView_macOS()
        #elseif os(iOS)
        SignUpView_iOS()
        #else
        // Fallback for other platforms
        Text("Sign Up - Platform not supported")
        #endif
    }
}

#Preview {
    #if os(macOS)
    SignUpView_macOS()
    #else
    SignUpView_iOS()
    #endif
}
