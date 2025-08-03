//
//  EbayAuthManager.swift
//  ResellAI
//
//  Complete eBay OAuth 2.0 Authentication Manager
//

import SwiftUI
import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Complete eBay OAuth 2.0 Authentication Manager
class EbayAuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authenticationStatus = "Not signed in"
    @Published var userProfile: EbayUserProfile?
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    static let shared = EbayAuthManager()
    
    private let clientId = Configuration.ebayAPIKey
    private let clientSecret = Configuration.ebayClientSecret
    private let redirectURI = Configuration.ebayRedirectURI
    private let environment = Configuration.ebayEnvironment
    
    // OAuth URLs
    private var authURL: String {
        return environment == "SANDBOX" ?
            "https://auth.sandbox.ebay.com/oauth2/authorize" :
            "https://auth.ebay.com/oauth2/authorize"
    }
    
    private var tokenURL: String {
        return environment == "SANDBOX" ?
            "https://api.sandbox.ebay.com/identity/v1/oauth2/token" :
            "https://api.ebay.com/identity/v1/oauth2/token"
    }
    
    private var userInfoURL: String {
        return environment == "SANDBOX" ?
            "https://apiz.sandbox.ebay.com/commerce/identity/v1/user" :
            "https://apiz.ebay.com/commerce/identity/v1/user"
    }
    
    // eBay OAuth scopes for listing items
    private let requiredScopes = [
        "https://api.ebay.com/oauth/api_scope/sell.marketing",
        "https://api.ebay.com/oauth/api_scope/sell.inventory",
        "https://api.ebay.com/oauth/api_scope/sell.account",
        "https://api.ebay.com/oauth/api_scope/sell.fulfillment"
    ].joined(separator: " ")
    
    // Token storage keys
    private let accessTokenKey = "ebay_access_token"
    private let refreshTokenKey = "ebay_refresh_token"
    private let tokenExpiryKey = "ebay_token_expiry"
    private let userProfileKey = "ebay_user_profile"
    
    // Token management
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: accessTokenKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: accessTokenKey)
            updateAuthenticationStatus()
        }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: refreshTokenKey) }
    }
    
    var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: tokenExpiryKey) }
    }
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    override init() {
        super.init()
        loadUserProfile()
        updateAuthenticationStatus()
        Configuration.validateConfiguration()
    }
    
    // MARK: - Public Authentication Methods
    
    func signInWithEbay(completion: @escaping (Bool) -> Void) {
        guard !clientId.isEmpty && !clientSecret.isEmpty else {
            print("❌ eBay OAuth credentials not configured")
            authenticationStatus = "eBay credentials missing"
            authError = "eBay API credentials are not configured. Please check Configuration.swift"
            completion(false)
            return
        }
        
        isAuthenticating = true
        authenticationStatus = "Signing in to eBay..."
        authError = nil
        
        print("🔐 Starting eBay OAuth 2.0 sign-in...")
        print("• Environment: \(environment)")
        print("• Client ID: \(clientId)")
        print("• Redirect URI: \(redirectURI)")
        
        // Check if we already have a valid token
        if hasValidToken() {
            print("✅ Already signed in with valid token")
            isAuthenticating = false
            completion(true)
            return
        }
        
        // Try to refresh token if we have one
        if let refreshToken = refreshToken {
            print("🔄 Attempting to refresh eBay token...")
            refreshAccessToken(refreshToken: refreshToken) { [weak self] success in
                self?.isAuthenticating = false
                if success {
                    completion(true)
                } else {
                    // Refresh failed, need new authorization
                    self?.performInitialAuthentication(completion: completion)
                }
            }
        } else {
            // No token at all, need initial authentication
            performInitialAuthentication(completion: completion)
        }
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        userProfile = nil
        isAuthenticated = false
        authenticationStatus = "Signed out"
        authError = nil
        
        // Clear user profile from storage
        UserDefaults.standard.removeObject(forKey: userProfileKey)
        
        print("🔓 eBay authentication cleared")
    }
    
    func hasValidToken() -> Bool {
        guard let token = accessToken,
              !token.isEmpty,
              let expiry = tokenExpiry,
              expiry > Date().addingTimeInterval(300) else { // 5 minute buffer
            return false
        }
        return true
    }
    
    // MARK: - Private Authentication Flow
    
    private func performInitialAuthentication(completion: @escaping (Bool) -> Void) {
        let state = UUID().uuidString
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // Store for later use
        UserDefaults.standard.set(codeVerifier, forKey: "ebay_code_verifier")
        UserDefaults.standard.set(state, forKey: "ebay_oauth_state")
        
        var urlComponents = URLComponents(string: authURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: requiredScopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authorizationURL = urlComponents.url else {
            print("❌ Failed to create eBay authorization URL")
            isAuthenticating = false
            authError = "Failed to create authorization URL"
            completion(false)
            return
        }
        
        print("🌐 Opening eBay authorization: \(authorizationURL)")
        
        webAuthSession = ASWebAuthenticationSession(
            url: authorizationURL,
            callbackURLScheme: "resellai"
        ) { [weak self] callbackURL, error in
            
            self?.isAuthenticating = false
            
            if let error = error {
                print("❌ eBay authentication error: \(error)")
                self?.authenticationStatus = "Sign-in failed"
                self?.authError = error.localizedDescription
                completion(false)
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("❌ No callback URL received")
                self?.authenticationStatus = "Sign-in cancelled"
                self?.authError = "Authentication was cancelled"
                completion(false)
                return
            }
            
            self?.handleAuthorizationCallback(url: callbackURL, codeVerifier: codeVerifier, completion: completion)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }
    
    private func handleAuthorizationCallback(url: URL, codeVerifier: String, completion: @escaping (Bool) -> Void) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let queryItems = urlComponents?.queryItems else {
            print("❌ Invalid callback URL format")
            authenticationStatus = "Invalid response from eBay"
            authError = "Invalid callback URL format"
            completion(false)
            return
        }
        
        // Check for error in callback
        if let errorCode = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? "Unknown error"
            print("❌ eBay OAuth error: \(errorCode) - \(errorDescription)")
            authenticationStatus = "Sign-in failed"
            authError = errorDescription
            completion(false)
            return
        }
        
        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let state = queryItems.first(where: { $0.name == "state" })?.value else {
            print("❌ Missing authorization code or state")
            authenticationStatus = "Invalid response from eBay"
            authError = "Missing authorization code"
            completion(false)
            return
        }
        
        // Verify state parameter
        let storedState = UserDefaults.standard.string(forKey: "ebay_oauth_state")
        guard state == storedState else {
            print("❌ State parameter mismatch - possible CSRF attack")
            authenticationStatus = "Security error"
            authError = "Security validation failed"
            completion(false)
            return
        }
        
        print("✅ Authorization code received, exchanging for token...")
        authenticationStatus = "Completing sign-in..."
        exchangeCodeForToken(authorizationCode: code, codeVerifier: codeVerifier, completion: completion)
    }
    
    private func exchangeCodeForToken(authorizationCode: String, codeVerifier: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenURL) else {
            authError = "Invalid token URL"
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create basic auth header
        let credentials = "\(clientId):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyParameters = [
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ]
        
        let bodyString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔄 Exchanging authorization code for access token...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Token exchange error: \(error)")
                    self?.authenticationStatus = "Failed to complete sign-in"
                    self?.authError = error.localizedDescription
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from token endpoint")
                    self?.authenticationStatus = "No response from eBay"
                    self?.authError = "No response from eBay servers"
                    completion(false)
                    return
                }
                
                // Log response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 Token response: \(responseString)")
                }
                
                do {
                    let tokenResponse = try JSONDecoder().decode(EbayTokenResponse.self, from: data)
                    self?.storeTokens(tokenResponse)
                    self?.fetchUserProfile { profileSuccess in
                        if profileSuccess {
                            print("✅ eBay sign-in successful!")
                            self?.authenticationStatus = "Signed in successfully"
                            completion(true)
                        } else {
                            print("⚠️ Token received but profile fetch failed")
                            self?.authenticationStatus = "Signed in (profile unavailable)"
                            completion(true)
                        }
                    }
                } catch {
                    print("❌ Failed to decode token response: \(error)")
                    self?.authenticationStatus = "Invalid response from eBay"
                    self?.authError = "Failed to process eBay response"
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientId):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyParameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔄 Refreshing eBay access token...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Token refresh error: \(error)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from refresh endpoint")
                    completion(false)
                    return
                }
                
                do {
                    let tokenResponse = try JSONDecoder().decode(EbayTokenResponse.self, from: data)
                    self?.storeTokens(tokenResponse)
                    print("✅ eBay token refreshed successfully")
                    completion(true)
                } catch {
                    print("❌ Failed to decode refresh response: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - User Profile
    
    private func fetchUserProfile(completion: @escaping (Bool) -> Void) {
        guard let accessToken = accessToken,
              let url = URL(string: userInfoURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ User profile fetch error: \(error)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("⚠️ No user profile data received")
                    completion(false)
                    return
                }
                
                do {
                    let profile = try JSONDecoder().decode(EbayUserProfile.self, from: data)
                    self?.userProfile = profile
                    self?.saveUserProfile()
                    print("✅ User profile loaded: \(profile.username)")
                    completion(true)
                } catch {
                    print("⚠️ Failed to decode user profile: \(error)")
                    // Don't fail the whole process for profile issues
                    completion(true)
                }
            }
        }.resume()
    }
    
    // MARK: - Storage Management
    
    private func storeTokens(_ tokenResponse: EbayTokenResponse) {
        accessToken = tokenResponse.access_token
        refreshToken = tokenResponse.refresh_token ?? refreshToken // Keep existing refresh token if not provided
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        tokenExpiry = expiryDate
        
        isAuthenticated = true
        
        print("🔐 eBay tokens stored successfully")
        print("🔐 Token expires: \(expiryDate)")
    }
    
    private func saveUserProfile() {
        if let profile = userProfile,
           let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userProfileKey)
        }
    }
    
    private func loadUserProfile() {
        if let data = UserDefaults.standard.data(forKey: userProfileKey),
           let profile = try? JSONDecoder().decode(EbayUserProfile.self, from: data) {
            userProfile = profile
        }
    }
    
    private func updateAuthenticationStatus() {
        isAuthenticated = hasValidToken()
        
        if isAuthenticated {
            if let username = userProfile?.username {
                authenticationStatus = "Signed in as \(username)"
            } else {
                authenticationStatus = "Signed in"
            }
        } else if refreshToken != nil {
            authenticationStatus = "Token expired - needs refresh"
        } else {
            authenticationStatus = "Not signed in"
        }
    }
    
    // MARK: - PKCE Helper Methods
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Public API Methods
    
    func canCreateListings() -> Bool {
        return isAuthenticated && hasValidToken()
    }
    
    func getListingCapabilities() -> EbayListingCapabilities {
        return EbayListingCapabilities(
            canList: canCreateListings(),
            maxPhotos: 12,
            supportedFormats: ["FixedPrice", "Auction"],
            sellerLevel: userProfile?.registrationMarketplaceId == "EBAY_US" ? "Standard" : "Basic"
        )
    }
    
    func getAuthStatus() -> String {
        if isAuthenticated {
            return "✅ eBay Connected"
        } else if !clientId.isEmpty {
            return "🔐 Ready to connect"
        } else {
            return "❌ Not configured"
        }
    }
    
    func validateCredentials() -> Bool {
        return !clientId.isEmpty && !clientSecret.isEmpty
    }
    
    // MARK: - Testing Helper
    
    func testConfiguration() -> String {
        var status = "🧪 eBay Configuration Test:\n\n"
        
        status += "• Client ID: \(clientId.isEmpty ? "❌ Missing" : "✅ Set")\n"
        status += "• Client Secret: \(clientSecret.isEmpty ? "❌ Missing" : "✅ Set")\n"
        status += "• Environment: \(environment)\n"
        status += "• Redirect URI: \(redirectURI)\n"
        status += "• Auth URL: \(authURL)\n"
        status += "• Token URL: \(tokenURL)\n\n"
        
        if hasValidToken() {
            status += "🔐 Current Status: ✅ Authenticated\n"
            if let expiry = tokenExpiry {
                status += "• Token expires: \(expiry)\n"
            }
            if let username = userProfile?.username {
                status += "• User: \(username)\n"
            }
        } else {
            status += "🔐 Current Status: ❌ Not authenticated\n"
        }
        
        return status
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension EbayAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first!
    }
}
