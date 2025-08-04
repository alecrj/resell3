//
//  EbayService.swift
//  ResellAI
//
//  Complete eBay integration following iOS OAuth best practices
//

import Foundation
import SwiftUI

@MainActor
class EbayService: ObservableObject {
    @Published var authToken: EbayAuthToken?
    @Published var isAuthenticated = false
    
    private let clientId = Configuration.ebayAPIKey
    private let clientSecret = Configuration.ebayClientSecret
    private let redirectURI = "resellai://auth/ebay"
    
    init() {
        loadSavedToken()
    }
    
    // MARK: - Authentication (Following ChatGPT's iOS OAuth Pattern)
    
    func startOAuthFlow() -> URL? {
        print("🔐 Starting eBay OAuth for iOS app...")
        print("• Client ID: \(clientId)")
        print("• Redirect URI: \(redirectURI)")
        print("• Environment: \(Configuration.ebayEnvironment)")
        
        // Use simplified, working eBay scopes
        let scopes = [
            "https://api.ebay.com/oauth/api_scope",
            "https://api.ebay.com/oauth/api_scope/sell.inventory",
            "https://api.ebay.com/oauth/api_scope/sell.account",
            "https://api.ebay.com/oauth/api_scope/sell.fulfillment"
        ].joined(separator: " ")
        
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "ebay_oauth_state")
        
        // Build OAuth URL exactly as ChatGPT specified
        let baseURL = "https://auth.ebay.com/oauth2/authorize"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state)
        ]
        
        let authURL = components.url!
        print("🌐 OAuth URL: \(authURL.absoluteString)")
        
        return authURL
    }
    
    func handleAuthCallback(url: URL) async throws {
        print("📲 Handling OAuth callback: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw ResellAIError.ebayAuthError("Invalid callback URL")
        }
        
        // Check for errors
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value ?? "Unknown error"
            throw ResellAIError.ebayAuthError("eBay OAuth error: \(error) - \(description)")
        }
        
        // Extract authorization code
        guard let authCode = queryItems.first(where: { $0.name == "code" })?.value else {
            throw ResellAIError.ebayAuthError("No authorization code received")
        }
        
        // Verify state parameter
        if let receivedState = queryItems.first(where: { $0.name == "state" })?.value {
            let storedState = UserDefaults.standard.string(forKey: "ebay_oauth_state")
            guard receivedState == storedState else {
                throw ResellAIError.ebayAuthError("State mismatch - possible security issue")
            }
        }
        
        print("✅ Authorization code received: \(authCode.prefix(10))...")
        
        // Exchange code for token
        try await exchangeCodeForToken(authCode: authCode)
    }
    
    private func exchangeCodeForToken(authCode: String) async throws {
        print("🔄 Exchanging authorization code for access token...")
        
        let tokenURL = "https://api.ebay.com/identity/v1/oauth2/token"
        
        guard let url = URL(string: tokenURL) else {
            throw ResellAIError.ebayAuthError("Invalid token URL")
        }
        
        // Create Basic Auth header (base64 encoded client_id:client_secret)
        let credentials = "\(clientId):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        
        // Create form-encoded request body
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": authCode,
            "redirect_uri": redirectURI
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("📤 Making token exchange request...")
        print("🔐 Auth header: Basic \(base64Credentials.prefix(20))...")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResellAIError.ebayAuthError("Invalid response")
        }
        
        print("📊 Token response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Token response: \(responseString)")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ResellAIError.ebayAuthError("Token exchange failed (\(httpResponse.statusCode)): \(errorMsg)")
        }
        
        // Parse token response
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            let token = EbayAuthToken(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token ?? "",
                expiresIn: tokenResponse.expires_in,
                tokenType: tokenResponse.token_type,
                createdAt: Date()
            )
            
            // Save and update state
            authToken = token
            isAuthenticated = true
            saveToken(token)
            
            print("✅ eBay OAuth successful!")
            print("🔐 Access token: \(tokenResponse.access_token.prefix(20))...")
            print("⏰ Expires in: \(tokenResponse.expires_in) seconds")
            
        } catch {
            print("❌ Failed to parse token response: \(error)")
            throw ResellAIError.ebayAuthError("Failed to parse token: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Token Management
    
    private func saveToken(_ token: EbayAuthToken) {
        if let encoded = try? JSONEncoder().encode(token) {
            UserDefaults.standard.set(encoded, forKey: "ebay_auth_token")
            print("💾 Token saved to UserDefaults")
        }
    }
    
    private func loadSavedToken() {
        guard let data = UserDefaults.standard.data(forKey: "ebay_auth_token"),
              let token = try? JSONDecoder().decode(EbayAuthToken.self, from: data) else {
            print("📱 No saved eBay token found")
            return
        }
        
        if !token.isExpired {
            authToken = token
            isAuthenticated = true
            print("✅ Loaded valid saved eBay token")
        } else {
            print("⚠️ Saved eBay token expired")
        }
    }
    
    func logout() {
        authToken = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "ebay_auth_token")
        UserDefaults.standard.removeObject(forKey: "ebay_oauth_state")
        print("🔓 eBay logout complete")
    }
    
    // MARK: - Search Sold Comps (RapidAPI)
    
    func searchSoldComps(searchTerms: [String], category: String) async throws -> [EbayComp] {
        let searchQuery = searchTerms.joined(separator: " ")
        print("🔍 Searching eBay sold comps for: \(searchQuery)")
        return try await searchRapidAPIComps(query: searchQuery)
    }
    
    private func searchRapidAPIComps(query: String) async throws -> [EbayComp] {
        let rapidAPIKey = Configuration.rapidAPIKey
        
        guard !rapidAPIKey.isEmpty else {
            throw ResellAIError.configurationError("RapidAPI key not configured")
        }
        
        let apiURL = "https://ebay-average-selling-price.p.rapidapi.com/findCompletedItems"
        
        guard let url = URL(string: apiURL) else {
            throw ResellAIError.ebaySearchError("Invalid RapidAPI URL")
        }
        
        let requestBody: [String: Any] = [
            "keywords": query,
            "max_search_results": 50,
            "category_id": "0",
            "site_id": "0"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("ebay-average-selling-price.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ResellAIError.ebaySearchError("Failed to create request body")
        }
        
        print("📡 Making RapidAPI request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResellAIError.ebaySearchError("Invalid response from RapidAPI")
        }
        
        print("📊 RapidAPI response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 429 {
            throw ResellAIError.ebaySearchError("RapidAPI rate limit exceeded")
        }
        
        if httpResponse.statusCode == 403 {
            throw ResellAIError.ebaySearchError("RapidAPI authentication failed")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ResellAIError.ebaySearchError("RapidAPI failed (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        return try parseRapidAPIResponse(data)
    }
    
    private func parseRapidAPIResponse(_ data: Data) throws -> [EbayComp] {
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 RapidAPI response: \(responseString.prefix(500))...")
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [] // Return empty array for invalid JSON
            }
            
            // Try different response structures
            var itemsArray: [[String: Any]]?
            
            if let items = json["items"] as? [[String: Any]] {
                itemsArray = items
            } else if let searchResult = json["searchResult"] as? [String: Any],
                      let items = searchResult["item"] as? [[String: Any]] {
                itemsArray = items
            } else if let completedItems = json["completedItems"] as? [[String: Any]] {
                itemsArray = completedItems
            } else if let results = json["results"] as? [[String: Any]] {
                itemsArray = results
            } else if let data = json["data"] as? [[String: Any]] {
                itemsArray = data
            } else {
                // Search for any array of dictionaries
                for (_, value) in json {
                    if let array = value as? [[String: Any]], !array.isEmpty {
                        itemsArray = array
                        break
                    }
                }
            }
            
            guard let items = itemsArray, !items.isEmpty else {
                print("⚠️ No items found in RapidAPI response")
                return []
            }
            
            return parseItemsArray(items)
            
        } catch {
            print("❌ Error parsing RapidAPI response: \(error)")
            return [] // Return empty array instead of throwing
        }
    }
    
    private func parseItemsArray(_ items: [[String: Any]]) -> [EbayComp] {
        var comps: [EbayComp] = []
        
        for (index, item) in items.enumerated() {
            // Extract title
            guard let title = extractString(from: item, keys: ["title", "itemTitle", "name"]) else {
                continue
            }
            
            // Extract price
            guard let price = extractPrice(from: item) else {
                continue
            }
            
            // Extract other fields
            let condition = extractString(from: item, keys: ["condition", "conditionDisplayName"]) ?? "Used"
            let soldDate = extractDate(from: item) ?? Date()
            let url = extractString(from: item, keys: ["viewItemURL", "itemURL", "url"]) ?? ""
            let imageURL = extractString(from: item, keys: ["galleryURL", "imageURL", "pictureURL"])
            let shippingCost = extractShippingCost(from: item)
            
            let comp = EbayComp(
                title: title,
                price: price,
                condition: condition,
                soldDate: soldDate,
                url: url,
                imageURL: imageURL,
                shippingCost: shippingCost
            )
            
            comps.append(comp)
        }
        
        print("✅ Parsed \(comps.count) valid comps from \(items.count) items")
        return comps.sorted { $0.soldDate > $1.soldDate }
    }
    
    // MARK: - Helper Methods
    
    private func extractString(from item: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = item[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    private func extractPrice(from item: [String: Any]) -> Double? {
        if let priceString = item["price"] as? String {
            return parsePrice(priceString)
        }
        if let priceDouble = item["price"] as? Double {
            return priceDouble
        }
        if let sellingStatus = item["sellingStatus"] as? [String: Any],
           let currentPrice = sellingStatus["currentPrice"] as? [String: Any],
           let priceString = currentPrice["__value__"] as? String {
            return parsePrice(priceString)
        }
        return nil
    }
    
    private func parsePrice(_ priceString: String) -> Double? {
        let cleanPrice = priceString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleanPrice)
    }
    
    private func extractDate(from item: [String: Any]) -> Date? {
        let dateKeys = ["endTime", "soldDate", "completedDate"]
        
        for key in dateKeys {
            if let dateString = item[key] as? String {
                return parseDate(dateString)
            }
        }
        return nil
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "MMM dd, yyyy"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
    
    private func extractShippingCost(from item: [String: Any]) -> Double {
        if let shippingString = item["shippingCost"] as? String {
            return parsePrice(shippingString) ?? 0
        }
        if let shippingDouble = item["shippingCost"] as? Double {
            return shippingDouble
        }
        return 0
    }
    
    // MARK: - Post Listing to eBay
    
    func postListing(_ listing: EbayListing) async throws -> String {
        guard let token = authToken, !token.isExpired else {
            throw ResellAIError.ebayAuthError("Not authenticated or token expired")
        }
        
        print("📤 Posting listing to eBay: \(listing.title)")
        
        // Create simplified listing for eBay Inventory API
        let sku = "RESELLAI-\(UUID().uuidString.prefix(8))"
        let listingData: [String: Any] = [
            "sku": sku,
            "product": [
                "title": listing.title,
                "description": listing.description,
                "aspects": listing.itemSpecifics
            ],
            "condition": listing.conditionID,
            "availability": [
                "shipToLocationAvailability": [
                    "quantity": 1
                ]
            ]
        ]
        
        let apiURL = "https://api.ebay.com/sell/inventory/v1/inventory_item"
        
        guard let url = URL(string: apiURL) else {
            throw ResellAIError.ebayListingError("Invalid API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: listingData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResellAIError.ebayListingError("Invalid response")
        }
        
        if 200...299 ~= httpResponse.statusCode {
            print("✅ Successfully posted listing!")
            return sku
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ eBay listing failed: \(errorMessage)")
            throw ResellAIError.ebayListingError("Listing failed: \(errorMessage)")
        }
    }
}

// MARK: - Supporting Models

private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}
