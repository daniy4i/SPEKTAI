//
//  NewProjectView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct NewProjectView: View {
    var body: some View {
        #if os(macOS)
        NewProjectView_macOS()
        #elseif os(iOS)
        NewProjectView_iOS()
        #else
        // Fallback for other platforms
        Text("New Project - Platform not supported")
        #endif
    }
}

#Preview {
    #if os(macOS)
    NewProjectView_macOS()
    #else
    NewProjectView_iOS()
    #endif
}
