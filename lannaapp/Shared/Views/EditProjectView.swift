//
//  EditProjectView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct EditProjectView: View {
    let project: Project
    
    var body: some View {
        #if os(macOS)
        EditProjectView_macOS(project: project)
        #elseif os(iOS)
        EditProjectView_iOS(project: project)
        #else
        // Fallback for other platforms
        Text("Edit Project - Platform not supported")
        #endif
    }
}

#Preview {
    EditProjectView(project: Project.mockProjects[0])
}
