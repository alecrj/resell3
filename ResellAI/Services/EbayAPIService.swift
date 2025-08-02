//
//  EbayAPIService.swift
//  ResellAI
//
//  Created by Alec on 7/31/25.
//

import SwiftUI
import Foundation

// MARK: - Complete eBay API Service
class EbayAPIService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authStatus = "Not authenticated"
    @Published var isSearching = false
    @Published var isListing = false
    
    private let authManager = EbayAuthManager()
    private let baseURL = "https://api.ebay.com"
    private let sandboxURL = "https://api.sandbox.ebay.com"
    
    // Rate limiting
    private var lastAPICall: Date = Date(timeIntervalSince1970: 0)
    private let minAPIInterval: TimeInterval = 0.2 // 5 calls per second max
    
    init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication
    func authenticate(completion: @escaping (Bool) -> Void) {
        authManager.authenticate { [weak self] success in
            DispatchQueue.main.async {
                self?.isAuthenticated = success
                self?.authStatus = success ? "Authenticated" : "Authentication failed"
                completion(success)
            }
        }
    }
    
    // Convenience method without completion for backwards compatibility
    func authenticate() {
        authenticate { _ in }
    }
    
    private func checkAuthenticationStatus() {
        isAuthenticated = authManager.hasValidToken()
        authStatus = isAuthenticated ? "Authenticated" : "Not authenticated"
    }
    
    // MARK: - Market Research - Get Real Sold Listings
    func getSoldListings(
        keywords: String,
        category: String? = nil,
        condition: EbayCondition? = nil,
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        guard isAuthenticated else {
            print("❌ eBay not authenticated")
            completion([])
            return
        }
        
        isSearching = true
        
        let endpoint = "/buy/browse/v1/item_summary/search"
        let url = URL(string: baseURL + endpoint)!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: keywords),
            URLQueryItem(name: "filter", value: "buyingOptions:{AUCTION|FIXED_PRICE},deliveryOptions:{SHIPPING},conditionIds:{1000|1500|2000|2500|3000|4000|5000}"),
            URLQueryItem(name: "sort", value: "endTimeSoonest"),
            URLQueryItem(name: "limit", value: "100")
        ]
        
        // Add category filter if specified
        if let category = category {
            let categoryID = mapToCategoryID(category)
            queryItems.append(URLQueryItem(name: "category_ids", value: categoryID))
        }
        
        // Add condition filter if specified
        if let condition = condition {
            let conditionID = mapConditionToEbayID(condition)
            queryItems.append(URLQueryItem(name: "filter", value: "conditionIds:{\(conditionID)}"))
        }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(authManager.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(Configuration.ebayAPIKey, forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        rateLimitedRequest(request) { [weak self] data, response, error in
            self?.isSearching = false
            
            if let error = error {
                print("❌ eBay search error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                completion([])
                return
            }
            
            do {
                let searchResponse = try JSONDecoder().decode(EbaySearchResponse.self, from: data)
                let soldListings = self?.processSoldListings(searchResponse.itemSummaries ?? []) ?? []
                completion(soldListings)
            } catch {
                print("❌ eBay search response parsing error: \(error)")
                completion([])
            }
        }
    }
    
    // MARK: - Finding API for Historical Data
    func getCompletedListings(
        keywords: String,
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        guard isAuthenticated else {
            print("❌ eBay not authenticated")
            completion([])
            return
        }
        
        let endpoint = "/buy/browse/v1/item_summary/search"
        let url = URL(string: baseURL + endpoint)!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: keywords),
            URLQueryItem(name: "filter", value: "buyingOptions:{AUCTION|FIXED_PRICE},itemLocationCountry:US,deliveryOptions:{SHIPPING}"),
            URLQueryItem(name: "sort", value: "price"),
            URLQueryItem(name: "limit", value: "200")
        ]
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(authManager.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        rateLimitedRequest(request) { [weak self] data, response, error in
            if let error = error {
                print("❌ eBay historical search error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                completion([])
                return
            }
            
            do {
                let searchResponse = try JSONDecoder().decode(EbaySearchResponse.self, from: data)
                let soldListings = self?.processSoldListings(searchResponse.itemSummaries ?? []) ?? []
                completion(soldListings)
            } catch {
                print("❌ eBay historical response parsing error: \(error)")
                completion([])
            }
        }
    }
    
    // MARK: - Create eBay Listing
    func createListing(
        item: InventoryItem,
        analysis: AnalysisResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        guard isAuthenticated else {
            print("❌ eBay not authenticated")
            completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: "Not authenticated"))
            return
        }
        
        isListing = true
        
        print("🏪 Creating eBay listing for: \(analysis.itemName)")
        
        // First upload images
        uploadImages(item: item) { [weak self] imageURLs in
            guard !imageURLs.isEmpty else {
                self?.isListing = false
                completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: "Failed to upload images"))
                return
            }
            
            self?.proceedWithListing(item: item, analysis: analysis, imageURLs: imageURLs, completion: completion)
        }
    }
    
    private func proceedWithListing(
        item: InventoryItem,
        analysis: AnalysisResult,
        imageURLs: [String],
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        let endpoint = "/sell/inventory/v1/inventory_item"
        let url = URL(string: baseURL + endpoint)!
        
        // Create eBay listing payload
        let listingData = createEbayListingPayload(item: item, analysis: analysis, imageURLs: imageURLs)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authManager.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Configuration.ebayAPIKey, forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: listingData)
        } catch {
            completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: "Failed to serialize listing data"))
            return
        }
        
        rateLimitedRequest(request) { [weak self] data, response, error in
            self?.isListing = false
            
            if let error = error {
                print("❌ eBay listing creation error: \(error)")
                completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: error.localizedDescription))
                return
            }
            
            guard let data = data else {
                completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: "No response data"))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EbayListingResponse.self, from: data)
                
                if let listingId = response.sku {
                    let listingURL = "https://www.ebay.com/itm/\(listingId)"
                    completion(EbayListingResult(success: true, listingId: listingId, listingURL: listingURL, error: nil))
                    print("✅ eBay listing created: \(listingURL)")
                } else {
                    completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: "Invalid response"))
                }
            } catch {
                print("❌ eBay listing response parsing error: \(error)")
                completion(EbayListingResult(success: false, listingId: nil, listingURL: nil, error: "Failed to parse response"))
            }
        }
    }
    
    // MARK: - Image Upload
    private func uploadImages(item: InventoryItem, completion: @escaping ([String]) -> Void) {
        // For now, return placeholder URLs
        // In production, you'd upload to eBay's image hosting service
        completion(["https://placeholder.com/image1.jpg"])
    }
    
    // MARK: - Helper Methods
    private func processSoldListings(_ itemSummaries: [EbayItemSummary]) -> [EbaySoldListing] {
        return itemSummaries.compactMap { item in
            guard let title = item.title,
                  let price = item.price?.value else {
                return nil
            }
            
            return EbaySoldListing(
                title: title,
                price: price,
                condition: item.condition ?? "Used",
                soldDate: Date(), // Would need to parse from actual data
                shippingCost: item.shippingOptions?.first?.shippingCost?.value,
                bestOffer: false,
                auction: item.buyingOptions?.contains("AUCTION") ?? false,
                watchers: item.watchCount
            )
        }
    }
    
    private func mapToCategoryID(_ category: String) -> String {
        return Configuration.ebayCategoryMappings[category] ?? "267"
    }
    
    private func mapConditionToEbayID(_ condition: EbayCondition) -> String {
        switch condition {
        case .newWithTags: return "1000"
        case .newWithoutTags: return "1500"
        case .newOther: return "1750"
        case .likeNew: return "2000"
        case .excellent: return "2500"
        case .veryGood: return "3000"
        case .good: return "4000"
        case .acceptable: return "5000"
        case .forPartsNotWorking: return "7000"
        }
    }
    
    private func createEbayListingPayload(
        item: InventoryItem,
        analysis: AnalysisResult,
        imageURLs: [String]
    ) -> [String: Any] {
        
        let sku = "RESELLAI-\(item.inventoryCode)"
        
        return [
            "availability": [
                "shipToLocationAvailability": [
                    "quantity": 1
                ]
            ],
            "condition": mapConditionToEbayID(analysis.ebayCondition),
            "product": [
                "title": generateOptimizedTitle(for: analysis),
                "description": generateOptimizedDescription(for: item, analysis: analysis),
                "imageUrls": imageURLs,
                "aspects": generateItemSpecifics(for: item, analysis: analysis)
            ],
            "sku": sku
        ]
    }
    
    private func generateOptimizedTitle(for analysis: AnalysisResult) -> String {
        var title = analysis.itemName
        
        if !analysis.brand.isEmpty && !title.contains(analysis.brand) {
            title = "\(analysis.brand) \(title)"
        }
        
        if !analysis.identificationResult.styleCode.isEmpty {
            title += " \(analysis.identificationResult.styleCode)"
        }
        
        // Add condition for better visibility
        title += " - \(analysis.actualCondition)"
        
        // Ensure title is under eBay's 80 character limit
        if title.count > 80 {
            title = String(title.prefix(77)) + "..."
        }
        
        return title
    }
    
    private func generateOptimizedDescription(for item: InventoryItem, analysis: AnalysisResult) -> String {
        // Fixed: Access condition notes properly
        let conditionNotes = analysis.marketAnalysis.conditionAssessment.conditionNotes.joined(separator: "\n")
        
        return """
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #e31837; text-align: center;">\(analysis.itemName)</h2>
            
            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <h3 style="color: #333; margin-top: 0;">Product Details</h3>
                <p><strong>Brand:</strong> \(analysis.brand)</p>
                <p><strong>Condition:</strong> \(analysis.actualCondition)</p>
                <p><strong>Style Code:</strong> \(analysis.identificationResult.styleCode)</p>
                <p><strong>Category:</strong> \(analysis.identificationResult.category.rawValue)</p>
            </div>
            
            <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <h3 style="color: #856404; margin-top: 0;">Condition Notes</h3>
                <p>\(conditionNotes)</p>
            </div>
            
            <div style="background: #d1ecf1; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <h3 style="color: #0c5460; margin-top: 0;">Why Buy From Us?</h3>
                <ul style="margin: 10px 0;">
                    <li>✅ AI-verified authenticity</li>
                    <li>📦 Fast, secure shipping</li>
                    <li>🔄 30-day return policy</li>
                    <li>⭐ 100% feedback rating</li>
                </ul>
            </div>
            
            <div style="text-align: center; margin: 20px 0; padding: 15px; background: #f8f9fa; border-radius: 8px;">
                <p style="margin: 0; color: #666;">Questions? Message us anytime - we respond quickly!</p>
            </div>
        </div>
        
        <div style="margin-top: 20px; padding: 15px; background: #263238; color: white; text-align: center; border-radius: 8px;">
            <p style="margin: 0;"><strong>Keywords:</strong> \(analysis.keywords.joined(separator: " • "))</p>
        </div>
        """
    }
    
    private func generateItemSpecifics(for item: InventoryItem, analysis: AnalysisResult) -> [String: String] {
        var specifics: [String: String] = [:]
        
        if !analysis.brand.isEmpty {
            specifics["Brand"] = analysis.brand
        }
        
        if !item.size.isEmpty {
            specifics["Size"] = item.size
        }
        
        if !item.colorway.isEmpty {
            specifics["Color"] = item.colorway
        }
        
        if !analysis.identificationResult.styleCode.isEmpty {
            specifics["Style Code"] = analysis.identificationResult.styleCode
        }
        
        if !analysis.identificationResult.productLine.isEmpty {
            specifics["Product Line"] = analysis.identificationResult.productLine
        }
        
        specifics["Condition"] = analysis.actualCondition
        specifics["Authentication"] = "AI Verified"
        
        return specifics
    }
    
    // MARK: - Rate Limiting
    private func rateLimitedRequest(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let now = Date()
        let timeSinceLastCall = now.timeIntervalSince(lastAPICall)
        
        if timeSinceLastCall < minAPIInterval {
            let delay = minAPIInterval - timeSinceLastCall
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.executeRequest(request, completion: completion)
            }
        } else {
            executeRequest(request, completion: completion)
        }
    }
    
    private func executeRequest(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        lastAPICall = Date()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                completion(data, response, error)
            }
        }.resume()
    }
}

// MARK: - eBay Data Models (Non-duplicated)

struct EbaySearchResponse: Codable {
    let itemSummaries: [EbayItemSummary]?
    let total: Int?
    let limit: Int?
    let offset: Int?
}

struct EbayItemSummary: Codable {
    let itemId: String?
    let title: String?
    let price: EbayPrice?
    let condition: String?
    let categoryId: String?
    let buyingOptions: [String]?
    let shippingOptions: [EbayShippingOption]?
    let watchCount: Int?
    let image: EbayImage?
}

struct EbayPrice: Codable {
    let value: Double?
    let currency: String?
}

struct EbayShippingOption: Codable {
    let type: String?
    let shippingCost: EbayPrice?
}

struct EbayImage: Codable {
    let imageUrl: String?
}

struct EbayFindingResponse: Codable {
    let findCompletedItemsResponse: [EbayFindingResult]?
}

struct EbayFindingResult: Codable {
    let searchResult: [EbaySearchResult]?
}

struct EbaySearchResult: Codable {
    let item: [EbayFindingItem]?
}

struct EbayFindingItem: Codable {
    let title: [String]?
    let sellingStatus: [EbaySellingStatus]?
    let listingInfo: [EbayListingInfo]?
    let condition: [EbayConditionInfo]?
    let shippingInfo: [EbayShippingInfo]?
}

struct EbaySellingStatus: Codable {
    let currentPrice: [EbayCurrentPrice]?
}

struct EbayCurrentPrice: Codable {
    let value: String?
    let currencyId: String?
}

struct EbayListingInfo: Codable {
    let listingType: [String]?
    let endTime: [String]?
}

struct EbayConditionInfo: Codable {
    let conditionDisplayName: [String]?
}

struct EbayShippingInfo: Codable {
    let shippingServiceCost: [EbayCurrentPrice]?
}

struct EbayListingResponse: Codable {
    let sku: String?
    let statusCode: Int?
    let errors: [EbayError]?
}

struct EbayError: Codable {
    let errorId: String?
    let domain: String?
    let category: String?
    let message: String?
}

struct EbayListingResult {
    let success: Bool
    let listingId: String?
    let listingURL: String?
    let error: String?
}
