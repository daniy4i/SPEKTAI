//
//  WatchContentView.swift
//  lannaappWatchApp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct WatchContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 24))
            
            Text("Hello, world!")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    WatchContentView()
}
