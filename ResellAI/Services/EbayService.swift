//
//  EbayService.swift
//  ResellAI
//
//  Created by Alec on 8/3/25.
//


//
//  EbayService.swift
//  ResellAI
//
//  Complete eBay integration: Auth, Comps, Listing
//

import Foundation
import SwiftUI

@MainActor
class EbayService: ObservableObject {
    @Published var authToken: EbayAuthToken?
    @Published var isAuthenticated = false
    
    private let appID = Configuration.ebayAPIKey
    private let clientSecret = Configuration.ebayClientSecret
    private let devID = Configuration.ebayDevId
    private let redirectURI = Configuration.ebayRedirectURI
    
    init() {
        loadSavedToken()
    }
    
    // MARK: - Authentication
    
    func startOAuthFlow() -> URL? {
        let scopes = Configuration.ebayRequiredScopes.joined(separator: " ")
        let state = UUID().uuidString
        
        var components = URLComponents(string: "\(Configuration.currentEbayAuthBase)/oauth2/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: appID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state)
        ]
        
        return components?.url
    }
    
    func handleAuthCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw ResellAIError.ebayAuthError("Invalid callback URL")
        }
        
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            let error = queryItems.first(where: { $0.name == "error" })?.value ?? "Unknown error"
            throw ResellAIError.ebayAuthError(error)
        }
        
        try await exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        let tokenURL = "\(Configuration.currentEbayAuthBase)/identity/v1/oauth2/token"
        
        guard let url = URL(string: tokenURL) else {
            throw ResellAIError.ebayAuthError("Invalid token URL")
        }
        
        let credentials = "\(appID):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI
        ]
        
        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ResellAIError.ebayAuthError("Token exchange failed")
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        let token = EbayAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? "",
            expiresIn: tokenResponse.expires_in,
            tokenType: tokenResponse.token_type,
            createdAt: Date()
        )
        
        authToken = token
        isAuthenticated = true
        saveToken(token)
    }
    
    private func saveToken(_ token: EbayAuthToken) {
        if let encoded = try? JSONEncoder().encode(token) {
            UserDefaults.standard.set(encoded, forKey: "ebay_auth_token")
        }
    }
    
    private func loadSavedToken() {
        guard let data = UserDefaults.standard.data(forKey: "ebay_auth_token"),
              let token = try? JSONDecoder().decode(EbayAuthToken.self, from: data) else {
            return
        }
        
        if !token.isExpired {
            authToken = token
            isAuthenticated = true
        }
    }
    
    func logout() {
        authToken = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "ebay_auth_token")
    }
    
    // MARK: - Search Sold Comps (RapidAPI)
    
    func searchSoldComps(searchTerms: [String], category: String) async throws -> [EbayComp] {
        let searchQuery = searchTerms.joined(separator: " ")
        return try await searchEbayCompsRapidAPI(query: searchQuery)
    }
    
    private func searchEbayCompsRapidAPI(query: String) async throws -> [EbayComp] {
        let rapidAPIKey = Configuration.rapidAPIKey
        
        guard !rapidAPIKey.isEmpty else {
            throw ResellAIError.configurationError("RapidAPI key not set")
        }
        
        // Using the correct RapidAPI eBay Average Selling Price endpoint from screenshot
        let rapidAPIURL = "https://ebay-average-selling-price.p.rapidapi.com/findCompletedItems"
        
        guard let url = URL(string: rapidAPIURL) else {
            throw ResellAIError.ebaySearchError("Invalid RapidAPI URL")
        }
        
        // Create request body as shown in the screenshot
        let requestBody: [String: Any] = [
            "keywords": query,
            "max_search_results": 50,
            "category_id": "0", // 0 means all categories
            "site_id": "0" // 0 means eBay US
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResellAIError.ebaySearchError("Invalid response from RapidAPI")
        }
        
        if httpResponse.statusCode == 429 {
            throw ResellAIError.ebaySearchError("RapidAPI rate limit exceeded")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ResellAIError.ebaySearchError("RapidAPI request failed (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        return try parseRapidAPIResponse(data)
    }
    
    private func parseRapidAPIResponse(_ data: Data) throws -> [EbayComp] {
        do {
            // First try to parse as the expected RapidAPI response format
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("RapidAPI Response: \(json)") // Debug log
                
                // Check if there's an items array or similar structure
                if let items = json["items"] as? [[String: Any]] {
                    return try parseItemsArray(items)
                } else if let searchResult = json["searchResult"] as? [String: Any],
                          let items = searchResult["item"] as? [[String: Any]] {
                    return try parseItemsArray(items)
                } else if let completedItems = json["completedItems"] as? [[String: Any]] {
                    return try parseItemsArray(completedItems)
                } else {
                    // If the structure is different, try to extract any array of items
                    for (key, value) in json {
                        if let itemsArray = value as? [[String: Any]], !itemsArray.isEmpty {
                            print("Found items array under key: \(key)")
                            return try parseItemsArray(itemsArray)
                        }
                    }
                }
            }
            
            // If we can't parse the expected format, return empty array
            print("Warning: Could not parse RapidAPI response format")
            return []
            
        } catch {
            print("RapidAPI parsing error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw ResellAIError.ebaySearchError("Failed to parse RapidAPI response: \(error.localizedDescription)")
        }
    }
    
    private func parseItemsArray(_ items: [[String: Any]]) throws -> [EbayComp] {
        var comps: [EbayComp] = []
        
        for item in items {
            // Try different possible field names for title
            guard let title = item["title"] as? String ?? 
                             item["itemTitle"] as? String ??
                             item["name"] as? String else {
                continue
            }
            
            // Try different possible field names for price
            let priceValue: Double
            if let priceString = item["price"] as? String {
                priceValue = Double(priceString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
            } else if let priceDouble = item["price"] as? Double {
                priceValue = priceDouble
            } else if let sellingStatus = item["sellingStatus"] as? [String: Any],
                      let currentPrice = sellingStatus["currentPrice"] as? [String: Any],
                      let priceString = currentPrice["__value__"] as? String {
                priceValue = Double(priceString) ?? 0
            } else {
                continue
            }
            
            // Try different possible field names for condition
            let condition = item["condition"] as? String ?? 
                           item["conditionDisplayName"] as? String ??
                           item["itemCondition"] as? String ?? 
                           "Used"
            
            // Try different possible field names for date
            let soldDate: Date
            if let endTimeString = item["endTime"] as? String {
                soldDate = parseRapidAPIDate(endTimeString) ?? Date()
            } else if let soldTimeString = item["soldDate"] as? String {
                soldDate = parseRapidAPIDate(soldTimeString) ?? Date()
            } else {
                soldDate = Date()
            }
            
            // Try different possible field names for URL
            let url = item["viewItemURL"] as? String ?? 
                     item["itemURL"] as? String ??
                     item["url"] as? String ?? 
                     ""
            
            // Try different possible field names for image
            let imageURL = item["galleryURL"] as? String ?? 
                          item["imageURL"] as? String ??
                          item["pictureURL"] as? String
            
            // Try different possible field names for shipping
            let shippingCost: Double
            if let shippingString = item["shippingCost"] as? String {
                shippingCost = Double(shippingString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
            } else if let shippingDouble = item["shippingCost"] as? Double {
                shippingCost = shippingDouble
            } else if let shippingInfo = item["shippingInfo"] as? [String: Any],
                      let shippingServiceCost = shippingInfo["shippingServiceCost"] as? [String: Any],
                      let costString = shippingServiceCost["__value__"] as? String {
                shippingCost = Double(costString) ?? 0
            } else {
                shippingCost = 0
            }
            
            let comp = EbayComp(
                title: title,
                price: priceValue,
                condition: condition,
                soldDate: soldDate,
                url: url,
                imageURL: imageURL,
                shippingCost: shippingCost
            )
            
            comps.append(comp)
        }
        
        return comps.sorted { $0.soldDate > $1.soldDate }
    }
    
    private func parseRapidAPIDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try alternative format
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.date(from: dateString)
    }
    
// MARK: - RapidAPI Response Models

private struct RapidAPIResponse: Codable {
    let items: [RapidAPIItem]
    let totalResults: Int?
    
    struct RapidAPIItem: Codable {
        let title: String
        let price: String
        let condition: String
        let endTime: String
        let itemURL: String
        let imageURL: String?
        let shippingCost: String?
    }
}

private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}
    
    // MARK: - Post Listing
    
    func postListing(_ listing: EbayListing) async throws -> String {
        guard let token = authToken, !token.isExpired else {
            throw ResellAIError.ebayAuthError("Not authenticated or token expired")
        }
        
        // Upload images first
        let imageURLs = try await uploadImages(listing.photos)
        
        // Create listing
        let listingData = createListingPayload(listing: listing, imageURLs: imageURLs)
        
        let url = URL(string: "\(Configuration.currentEbayAPIBase)/sell/inventory/v1/inventory_item")!
        
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
            // Parse the response to get the listing ID
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sku = json["sku"] as? String {
                return sku
            }
            return UUID().uuidString // Fallback ID
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ResellAIError.ebayListingError("Listing failed: \(errorMessage)")
        }
    }
    
    private func uploadImages(_ images: [Data]) async throws -> [String] {
        // For now, return placeholder URLs
        // In production, you'd upload to eBay's image service
        return images.enumerated().map { index, _ in
            "https://example.com/image\(index).jpg"
        }
    }
    
    private func createListingPayload(listing: EbayListing, imageURLs: [String]) -> [String: Any] {
        let sku = "RESELLAI-\(UUID().uuidString.prefix(8))"
        
        return [
            "sku": sku,
            "product": [
                "title": listing.title,
                "description": listing.description,
                "imageUrls": imageURLs,
                "aspects": listing.itemSpecifics
            ],
            "condition": listing.conditionID,
            "availability": [
                "shipToLocationAvailability": [
                    "quantity": 1
                ]
            ]
        ]
    }
}

// MARK: - Supporting Models

private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}