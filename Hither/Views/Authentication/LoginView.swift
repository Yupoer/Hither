//
//  LoginView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authService = AuthenticationService()
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Hither")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Stay Connected, Stay Safe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            if isSignUp {
                                await authService.signUpWithEmail(email, password: password, displayName: displayName)
                            } else {
                                await authService.signInWithEmail(email, password: password)
                            }
                        }
                    }) {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
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
                    ProgressView()
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
            .navigationBarHidden(true)
        }
    }
}