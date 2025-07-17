//
//  AuthenticationService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import UIKit
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
        
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = await windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get presenting view controller"
            isLoading = false
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get Google ID token"
                isLoading = false
                return
            }
            
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            let authResult = try await Auth.auth().signIn(with: credential)
            currentUser = HitherUser(from: authResult.user)
            isAuthenticated = true
            
        } catch {
            errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
        }
        
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
