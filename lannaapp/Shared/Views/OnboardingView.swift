//
//  OnboardingView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPageIndex = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    OnboardingPage.pages[currentPageIndex].primaryColor,
                    OnboardingPage.pages[currentPageIndex].secondaryColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Page content
                TabView(selection: $currentPageIndex) {
                    ForEach(Array(OnboardingPage.pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #else
                .tabViewStyle(DefaultTabViewStyle())
                #endif
                .animation(.easeInOut, value: currentPageIndex)
                
                // Custom navigation controls
                VStack(spacing: 20) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<OnboardingPage.pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPageIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: index == currentPageIndex ? 12 : 8, height: index == currentPageIndex ? 12 : 8)
                                .animation(.easeInOut, value: currentPageIndex)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 20) {
                        if currentPageIndex > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentPageIndex -= 1
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                        }
                        
                        Spacer()
                        
                        if currentPageIndex < OnboardingPage.pages.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPageIndex += 1
                                }
                            }
                            .foregroundColor(OnboardingPage.pages[currentPageIndex].primaryColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(25)
                        } else {
                            Button("Setup Smart Glasses") {
                                isOnboardingComplete = true
                            }
                            .foregroundColor(OnboardingPage.pages[currentPageIndex].primaryColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Content
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                
                Text(page.subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
