//
//  AuthenticationService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn

@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentUser: HitherUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.currentUser = HitherUser(from: user)
                    self?.isAuthenticated = true
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
                self?.isLoading = false
            }
        }
    }
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            // Note: In a real implementation, you'd need to implement ASAuthorizationControllerDelegate
            // and handle the sign-in flow properly
            
        } catch {
            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        // Note: Google Sign-In would require additional setup in a real implementation
        // This is a placeholder for the Google Sign-In flow
        errorMessage = "Google Sign-In not implemented yet"
        isLoading = false
    }
    
    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = HitherUser(from: result.user)
            isAuthenticated = true
        } catch {
            errorMessage = "Email sign-in failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func signUpWithEmail(_ email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            currentUser = HitherUser(from: result.user)
            isAuthenticated = true
        } catch {
            errorMessage = "Email sign-up failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Sign-out failed: \(error.localizedDescription)"
        }
    }
}