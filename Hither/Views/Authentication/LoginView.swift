//
//  LoginView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var locationService = LocationService()
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isButtonPressed = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("app_name".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("app_subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("display_name".localized, text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                // Move focus to email field when Enter is pressed
                            }
                    }
                    
                    TextField("email".localized, text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onSubmit {
                            // Move focus to password field when Enter is pressed
                        }
                    
                    SecureField("password".localized, text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            // Trigger sign in when Enter is pressed on password field
                            handleSignIn()
                        }
                    
                    Button(action: {
                        // Immediate feedback
                        isButtonPressed = true
                        
                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        Task {
                            if isSignUp {
                                await authService.signUpWithEmail(email, password: password, displayName: displayName)
                            } else {
                                await authService.signInWithEmail(email, password: password)
                            }
                            
                            // Reset button state
                            await MainActor.run {
                                isButtonPressed = false
                            }
                        }
                    }) {
                        Text(isSignUp ? "sign_up".localized : "sign_in".localized)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isButtonPressed ? Color.blue.opacity(0.7) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .scaleEffect(isButtonPressed ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isButtonPressed)
                    }
                    .disabled(authService.isLoading || email.isEmpty || password.isEmpty || (isSignUp && displayName.isEmpty))
                    
                    Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                        isSignUp.toggle()
                        email = ""
                        password = ""
                        displayName = ""
                    }
                    .foregroundColor(.blue)
                }
                
                Divider()
                    .padding(.vertical)
                
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await authService.signInWithApple()
                        }
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Continue with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task {
                            await authService.signInWithGoogle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                if authService.isLoading {
                    SheepLoadingView(message: "Signing you in...")
                        .padding()
                }
                
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarHidden(false)
            .navigationBarItems(trailing: LanguagePicker(languageService: languageService))
            .onAppear {
                // Preload location services for better map performance
                locationService.preloadLocationServices()
            }
        }
    }
    
    private func handleSignIn() {
        // Only trigger sign in if all required fields are filled
        guard !email.isEmpty && !password.isEmpty else { return }
        if isSignUp && displayName.isEmpty { return }
        
        Task {
            if isSignUp {
                await authService.signUpWithEmail(email, password: password, displayName: displayName)
            } else {
                await authService.signInWithEmail(email, password: password)
            }
        }
    }
}