//
//  ContentView.swift
//  Spekt
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 50))
            
            Text("Spekt")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your Creative AI Assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            #if DEBUG
            Button("Reset Onboarding (Debug)") {
                hasCompletedOnboarding = false
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            #endif
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
