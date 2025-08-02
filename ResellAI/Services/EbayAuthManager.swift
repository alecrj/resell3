//
//  EbayAuthManager.swift
//  ResellAI
//
//  Created by Alec on 7/31/25.
//


import SwiftUI
import Foundation
import AuthenticationServices

// MARK: - eBay OAuth 2.0 Authentication Manager
class EbayAuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authenticationStatus = "Not authenticated"
    
    private let clientId = Configuration.ebayAPIKey
    private let redirectURI = "resellai://auth/ebay"
    private let scope = "https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/sell.marketing.readonly https://api.ebay.com/oauth/api_scope/sell.marketing https://api.ebay.com/oauth/api_scope/sell.inventory.readonly https://api.ebay.com/oauth/api_scope/sell.inventory https://api.ebay.com/oauth/api_scope/sell.account.readonly https://api.ebay.com/oauth/api_scope/sell.account https://api.ebay.com/oauth/api_scope/sell.fulfillment.readonly https://api.ebay.com/oauth/api_scope/sell.fulfillment https://api.ebay.com/oauth/api_scope/sell.analytics.readonly https://api.ebay.com/oauth/api_scope/sell.finances https://api.ebay.com/oauth/api_scope/sell.payment.dispute https://api.ebay.com/oauth/api_scope/commerce.identity.readonly"
    
    // OAuth URLs
    private let authURL = "https://auth.ebay.com/oauth2/authorize"
    private let tokenURL = "https://api.ebay.com/identity/v1/oauth2/token"
    private let sandboxAuthURL = "https://auth.sandbox.ebay.com/oauth2/authorize"
    private let sandboxTokenURL = "https://api.sandbox.ebay.com/identity/v1/oauth2/token"
    
    // Token storage
    private let accessTokenKey = "ebay_access_token"
    private let refreshTokenKey = "ebay_refresh_token"
    private let tokenExpiryKey = "ebay_token_expiry"
    
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
        updateAuthenticationStatus()
    }
    
    // MARK: - Public Authentication Methods
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        print("🔐 Starting eBay OAuth 2.0 authentication...")
        
        // Check if we already have a valid token
        if hasValidToken() {
            print("✅ Already authenticated with valid token")
            completion(true)
            return
        }
        
        // Try to refresh token if we have one
        if let refreshToken = refreshToken {
            print("🔄 Attempting to refresh eBay token...")
            refreshAccessToken(refreshToken: refreshToken) { success in
                if success {
                    completion(true)
                } else {
                    // Refresh failed, need new authorization
                    self.performInitialAuthentication(completion: completion)
                }
            }
        } else {
            // No token at all, need initial authentication
            performInitialAuthentication(completion: completion)
        }
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
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        authenticationStatus = "Signed out"
        print("🔓 eBay authentication cleared")
    }
    
    // MARK: - Private Authentication Flow
    
    private func performInitialAuthentication(completion: @escaping (Bool) -> Void) {
        let state = UUID().uuidString
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // Store for later use
        UserDefaults.standard.set(codeVerifier, forKey: "ebay_code_verifier")
        UserDefaults.standard.set(state, forKey: "ebay_oauth_state")
        
        var urlComponents = URLComponents(string: Configuration.ebayEnvironment == "SANDBOX" ? sandboxAuthURL : authURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authorizationURL = urlComponents.url else {
            print("❌ Failed to create eBay authorization URL")
            completion(false)
            return
        }
        
        print("🌐 Opening eBay authorization: \(authorizationURL)")
        
        webAuthSession = ASWebAuthenticationSession(
            url: authorizationURL,
            callbackURLScheme: "resellai"
        ) { [weak self] callbackURL, error in
            
            if let error = error {
                print("❌ eBay authentication error: \(error)")
                completion(false)
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("❌ No callback URL received")
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
            completion(false)
            return
        }
        
        // Verify state parameter
        let storedState = UserDefaults.standard.string(forKey: "ebay_oauth_state")
        guard state == storedState else {
            print("❌ State parameter mismatch - possible CSRF attack")
            completion(false)
            return
        }
        
        print("✅ Authorization code received, exchanging for token...")
        exchangeCodeForToken(authorizationCode: code, codeVerifier: codeVerifier, completion: completion)
    }
    
    private func exchangeCodeForToken(authorizationCode: String, codeVerifier: String, completion: @escaping (Bool) -> Void) {
        let tokenEndpoint = Configuration.ebayEnvironment == "SANDBOX" ? sandboxTokenURL : tokenURL
        guard let url = URL(string: tokenEndpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create basic auth header
        let credentials = "\(clientId):"
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
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from token endpoint")
                    completion(false)
                    return
                }
                
                do {
                    let tokenResponse = try JSONDecoder().decode(EbayTokenResponse.self, from: data)
                    self?.storeTokens(tokenResponse)
                    print("✅ eBay authentication successful!")
                    completion(true)
                } catch {
                    print("❌ Token response parsing error: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func refreshAccessToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        let tokenEndpoint = Configuration.ebayEnvironment == "SANDBOX" ? sandboxTokenURL : tokenURL
        guard let url = URL(string: tokenEndpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create basic auth header
        let credentials = "\(clientId):"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyParameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": scope
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
    
    // MARK: - Token Management
    
    private func storeTokens(_ tokenResponse: EbayTokenResponse) {
        accessToken = tokenResponse.access_token
        refreshToken = tokenResponse.refresh_token ?? refreshToken // Keep existing refresh token if not provided
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        tokenExpiry = expiryDate
        
        isAuthenticated = true
        authenticationStatus = "Authenticated"
        
        print("🔐 eBay tokens stored successfully")
        print("🔐 Token expires: \(expiryDate)")
    }
    
    private func updateAuthenticationStatus() {
        isAuthenticated = hasValidToken()
        
        if isAuthenticated {
            authenticationStatus = "Authenticated"
        } else if refreshToken != nil {
            authenticationStatus = "Token expired - needs refresh"
        } else {
            authenticationStatus = "Not authenticated"
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