//
//  EbayAuthManager.swift
//  ResellAI
//
//  Enhanced eBay OAuth 2.0 Authentication Manager with User Sign-In
//

import SwiftUI
import Foundation
import AuthenticationServices

// MARK: - Enhanced eBay OAuth 2.0 Authentication Manager
class EbayAuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authenticationStatus = "Not signed in"
    @Published var userProfile: EbayUserProfile?
    @Published var isAuthenticating = false
    
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
    
    // eBay OAuth scopes for listing items
    private let requiredScopes = [
        "https://api.ebay.com/oauth/api_scope/sell.marketing",
        "https://api.ebay.com/oauth/api_scope/sell.inventory",
        "https://api.ebay.com/oauth/api_scope/sell.account",
        "https://api.ebay.com/oauth/api_scope/sell.fulfillment"
    ].joined(separator: " ")
    
    // Token storage
    private let accessTokenKey = "ebay_access_token"
    private let refreshTokenKey = "ebay_refresh_token"
    private let tokenExpiryKey = "ebay_token_expiry"
    private let userProfileKey = "ebay_user_profile"
    
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
    }
    
    // MARK: - Public Authentication Methods
    
    func signInWithEbay(completion: @escaping (Bool) -> Void) {
        guard !clientId.isEmpty && !clientSecret.isEmpty else {
            print("❌ eBay OAuth credentials not configured")
            authenticationStatus = "eBay credentials missing"
            completion(false)
            return
        }
        
        isAuthenticating = true
        authenticationStatus = "Signing in to eBay..."
        
        print("🔐 Starting eBay OAuth 2.0 sign-in...")
        
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
                completion(false)
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("❌ No callback URL received")
                self?.authenticationStatus = "Sign-in cancelled"
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
        
        guard let queryItems = urlComponents?.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value,
              let state = queryItems.first(where: { $0.name == "state" })?.value else {
            print("❌ Invalid callback URL format")
            authenticationStatus = "Invalid response from eBay"
            completion(false)
            return
        }
        
        // Verify state parameter
        let storedState = UserDefaults.standard.string(forKey: "ebay_oauth_state")
        guard state == storedState else {
            print("❌ State parameter mismatch - possible CSRF attack")
            authenticationStatus = "Security error"
            completion(false)
            return
        }
        
        print("✅ Authorization code received, exchanging for token...")
        authenticationStatus = "Completing sign-in..."
        exchangeCodeForToken(authorizationCode: code, codeVerifier: codeVerifier, completion: completion)
    }
    
    private func exchangeCodeForToken(authorizationCode: String, codeVerifier: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenURL) else {
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Token exchange error: \(error)")
                    self?.authenticationStatus = "Failed to complete sign-in"
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from token endpoint")
                    self?.authenticationStatus = "No response from eBay"
                    completion(false)
                    return
                }
                
                do {
                    let tokenResponse = try JSONDecoder().decode(EbayTokenResponse.self, from: data)
                    self?.storeTokens(tokenResponse)
                    self?.fetchUserProfile { profileSuccess in
                        if profileSuccess {
                            print("✅ eBay sign-in successful!")
                            self?.authenticationStatus = "Signed in successfully"
                        } else {
                            print("⚠️ Signed in but failed to fetch profile")
                            self?.authenticationStatus = "Signed in (profile unavailable)"
                        }
                        completion(true)
                    }
                } catch {
                    print("❌ Token response parsing error: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    self?.authenticationStatus = "Failed to parse response"
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func refreshAccessToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenURL) else {
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
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": requiredScopes
        ]
        
        let bodyString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
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
                    print("✅ eBay token refreshed successfully!")
                    completion(true)
                } catch {
                    print("❌ Token refresh response parsing error: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - User Profile Management
    
    private func fetchUserProfile(completion: @escaping (Bool) -> Void) {
        guard let token = accessToken else {
            completion(false)
            return
        }
        
        let profileURL = environment == "SANDBOX" ?
            "https://api.sandbox.ebay.com/identity/v1/user" :
            "https://api.ebay.com/identity/v1/user"
        
        guard let url = URL(string: profileURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Profile fetch error: \(error)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ No profile data received")
                    completion(false)
                    return
                }
                
                do {
                    let profile = try JSONDecoder().decode(EbayUserProfile.self, from: data)
                    self?.userProfile = profile
                    self?.saveUserProfile(profile)
                    print("✅ User profile fetched: \(profile.username ?? "Unknown")")
                    completion(true)
                } catch {
                    print("❌ Profile parsing error: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func saveUserProfile(_ profile: EbayUserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: userProfileKey)
        } catch {
            print("❌ Failed to save user profile: \(error)")
        }
    }
    
    private func loadUserProfile() {
        guard let data = UserDefaults.standard.data(forKey: userProfileKey) else { return }
        
        do {
            userProfile = try JSONDecoder().decode(EbayUserProfile.self, from: data)
        } catch {
            print("❌ Failed to load user profile: \(error)")
        }
    }
    
    // MARK: - Token Management
    
    private func storeTokens(_ tokenResponse: EbayTokenResponse) {
        accessToken = tokenResponse.access_token
        refreshToken = tokenResponse.refresh_token ?? refreshToken // Keep existing refresh token if not provided
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        tokenExpiry = expiryDate
        
        isAuthenticated = true
        
        print("🔐 eBay tokens stored successfully")
        print("🔐 Token expires: \(expiryDate)")
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
        let challenge = Data(verifier.utf8)
        let hash = challenge.sha256()
        return hash.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Listing Management
    
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
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension EbayAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Data Extensions
extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }
}

// Add this import at the top
import CommonCrypto

// MARK: - eBay Token Response Model
struct EbayTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String?
}

// MARK: - eBay User Profile Model
struct EbayUserProfile: Codable {
    let userId: String?
    let username: String?
    let email: String?
    let individualAccount: Bool?
    let registrationMarketplaceId: String?
    let businessAccount: Bool?
}

// MARK: - eBay Listing Capabilities
struct EbayListingCapabilities {
    let canList: Bool
    let maxPhotos: Int
    let supportedFormats: [String]
    let sellerLevel: String
}
