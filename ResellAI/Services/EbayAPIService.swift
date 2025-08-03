//
//  EbayAPIService.swift
//  ResellAI
//
//  eBay API Service with Better Rate Limiting - Fallback for RapidAPI
//

import SwiftUI
import Foundation

// MARK: - eBay API Service - Fallback for Real eBay Data
class EbayAPIService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authStatus = "Not authenticated"
    @Published var isSearching = false
    @Published var isListing = false
    
    private let baseURL = "https://svcs.ebay.com/services/search/FindingService/v1"
    
    // Conservative rate limiting for eBay Finding API
    private var lastAPICall: Date = Date(timeIntervalSince1970: 0)
    private let minAPIInterval: TimeInterval = 5.0 // 5 seconds between calls
    private var callCount = 0
    private let maxCallsPerMinute = 3 // Very conservative
    private var rateLimitResetTime: Date = Date()
    private var consecutiveRateLimitErrors = 0
    
    // Retry logic
    private let maxRetries = 2
    private let baseRetryDelay: TimeInterval = 60.0 // 1 minute base delay
    
    init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    private func checkAuthenticationStatus() {
        isAuthenticated = !Configuration.ebayAPIKey.isEmpty
        authStatus = isAuthenticated ? "eBay Finding API Ready (Fallback)" : "eBay API Key missing"
        
        if isAuthenticated {
            print("🔍 eBay Finding API Ready as Fallback")
            print("• App ID: \(Configuration.ebayAPIKey)")
            print("• Rate Limit: \(maxCallsPerMinute) calls/minute, \(minAPIInterval)s between calls")
        }
    }
    
    // MARK: - Authentication Method
    func authenticate(completion: @escaping (Bool) -> Void) {
        let hasAuth = !Configuration.ebayAPIKey.isEmpty
        completion(hasAuth)
    }
    
    // MARK: - eBay Sold Comp Lookup (Fallback Method)
    func getSoldComps(
        keywords: [String],
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        guard isAuthenticated else {
            print("❌ eBay API not configured")
            completion([])
            return
        }
        
        guard !keywords.isEmpty else {
            print("❌ No keywords provided for eBay search")
            completion([])
            return
        }
        
        // Check if we're rate limited
        if consecutiveRateLimitErrors > 2 {
            print("⏰ eBay API rate limited - skipping search")
            completion([])
            return
        }
        
        isSearching = true
        
        // Create conservative search query
        let searchQuery = optimizeSearchQuery(keywords)
        print("🔍 eBay Finding API fallback search: \(searchQuery)")
        
        // Search with retry logic
        searchWithRetry(query: searchQuery, retryCount: 0) { [weak self] results in
            DispatchQueue.main.async {
                self?.isSearching = false
                completion(results)
            }
        }
    }
    
    // MARK: - Search with Conservative Retry Logic
    private func searchWithRetry(
        query: String,
        retryCount: Int,
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        // Check rate limiting
        let now = Date()
        let timeSinceLastCall = now.timeIntervalSince(lastAPICall)
        
        if timeSinceLastCall < minAPIInterval {
            let waitTime = minAPIInterval - timeSinceLastCall
            print("⏰ eBay API waiting \(Int(waitTime)) seconds for rate limit")
            
            DispatchQueue.global().asyncAfter(deadline: .now() + waitTime) {
                self.executeEbaySearch(query: query, retryCount: retryCount, completion: completion)
            }
        } else {
            executeEbaySearch(query: query, retryCount: retryCount, completion: completion)
        }
    }
    
    // MARK: - Execute eBay Search
    private func executeEbaySearch(
        query: String,
        retryCount: Int,
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        lastAPICall = Date()
        
        performEbaySearch(query: query) { [weak self] success, results in
            if success {
                // Reset consecutive errors on success
                self?.consecutiveRateLimitErrors = 0
                completion(results)
            } else {
                // Handle failure
                self?.consecutiveRateLimitErrors += 1
                
                if retryCount < self?.maxRetries ?? 0 {
                    let waitTime = self?.baseRetryDelay ?? 60.0
                    print("🔄 eBay API retry \(retryCount + 1)/\(self?.maxRetries ?? 0) in \(Int(waitTime)) seconds")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + waitTime) {
                        self?.searchWithRetry(
                            query: query,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                } else {
                    print("❌ eBay API max retries exceeded")
                    completion([])
                }
            }
        }
    }
    
    // MARK: - Perform eBay Finding API Search
    private func performEbaySearch(
        query: String,
        completion: @escaping (Bool, [EbaySoldListing]) -> Void
    ) {
        
        // Calculate date range - last 30 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let dateFormatter = ISO8601DateFormatter()
        let endDateString = dateFormatter.string(from: endDate)
        let startDateString = dateFormatter.string(from: startDate)
        
        // Build conservative eBay Finding API URL
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "OPERATION-NAME", value: "findCompletedItems"),
            URLQueryItem(name: "SERVICE-VERSION", value: "1.0.0"),
            URLQueryItem(name: "SECURITY-APPNAME", value: Configuration.ebayAPIKey),
            URLQueryItem(name: "RESPONSE-DATA-FORMAT", value: "JSON"),
            URLQueryItem(name: "keywords", value: query),
            URLQueryItem(name: "itemFilter(0).name", value: "SoldItemsOnly"),
            URLQueryItem(name: "itemFilter(0).value", value: "true"),
            URLQueryItem(name: "itemFilter(1).name", value: "EndTimeFrom"),
            URLQueryItem(name: "itemFilter(1).value", value: startDateString),
            URLQueryItem(name: "itemFilter(2).name", value: "EndTimeTo"),
            URLQueryItem(name: "itemFilter(2).value", value: endDateString),
            URLQueryItem(name: "paginationInput.entriesPerPage", value: "15"), // Even more conservative
            URLQueryItem(name: "sortOrder", value: "EndTimeSoonest")
        ]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to create eBay URL")
            completion(false, [])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 45.0
        
        print("🌐 eBay Finding API fallback call")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ eBay API network error: \(error)")
                completion(false, [])
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 eBay API response code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 429 {
                    print("⚠️ eBay API rate limited (429)")
                    completion(false, [])
                    return
                } else if httpResponse.statusCode != 200 {
                    print("❌ eBay API error: HTTP \(httpResponse.statusCode)")
                    completion(false, [])
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No data received from eBay API")
                completion(false, [])
                return
            }
            
            // Parse eBay response
            self?.parseEbayResponse(data: data) { success, listings in
                completion(success, listings)
            }
            
        }.resume()
    }
    
    // MARK: - eBay Response Parsing
    private func parseEbayResponse(
        data: Data,
        completion: @escaping (Bool, [EbaySoldListing]) -> Void
    ) {
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Check for eBay API errors first
            if let errorMessage = jsonResponse?["errorMessage"] as? [[String: Any]],
               let firstError = errorMessage.first,
               let error = firstError["error"] as? [[String: Any]],
               let firstErrorDetail = error.first,
               let message = firstErrorDetail["message"] as? [String],
               let errorMsg = message.first {
                
                print("❌ eBay API Error: \(errorMsg)")
                
                if errorMsg.contains("exceeded") || errorMsg.contains("rate") || errorMsg.contains("limit") {
                    print("🔄 eBay rate limit detected")
                    completion(false, [])
                    return
                } else {
                    print("❌ eBay API error: \(errorMsg)")
                    completion(false, [])
                    return
                }
            }
            
            // Parse successful response
            guard let findCompletedItemsResponse = jsonResponse?["findCompletedItemsResponse"] as? [[String: Any]],
                  let firstResponse = findCompletedItemsResponse.first else {
                print("❌ Invalid eBay response structure")
                completion(false, [])
                return
            }
            
            // Check if search was successful
            guard let ack = firstResponse["ack"] as? [String],
                  let ackValue = ack.first,
                  ackValue == "Success" else {
                print("❌ eBay search not successful")
                completion(false, [])
                return
            }
            
            // Extract search result
            guard let searchResult = firstResponse["searchResult"] as? [[String: Any]],
                  let firstResult = searchResult.first else {
                print("📄 No search results in eBay response")
                completion(true, []) // Success but no results
                return
            }
            
            // Check count
            if let count = firstResult["@count"] as? String,
               let itemCount = Int(count),
               itemCount == 0 {
                print("📄 eBay returned 0 sold items")
                completion(true, []) // Success but no results
                return
            }
            
            // Extract items
            guard let items = firstResult["item"] as? [[String: Any]] else {
                print("📄 No items array in eBay search results")
                completion(true, []) // Success but no results
                return
            }
            
            print("✅ eBay Finding API returned \(items.count) sold items")
            
            var soldListings: [EbaySoldListing] = []
            
            for item in items {
                if let soldListing = parseEbayItem(item: item) {
                    soldListings.append(soldListing)
                }
            }
            
            // Filter to last 30 days and sort by date
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let recentSoldListings = soldListings
                .filter { $0.soldDate >= thirtyDaysAgo }
                .sorted { $0.soldDate > $1.soldDate }
            
            print("✅ eBay processed \(recentSoldListings.count) recent sold items (last 30 days)")
            
            completion(true, recentSoldListings)
            
        } catch {
            print("❌ Error parsing eBay API response: \(error)")
            completion(false, [])
        }
    }
    
    // MARK: - Optimize Search Query (Very Conservative)
    private func optimizeSearchQuery(_ keywords: [String]) -> String {
        // Take only the most essential keywords
        let filteredKeywords = keywords.filter { keyword in
            let lower = keyword.lowercased()
            return !["the", "a", "an", "and", "or", "in", "on", "at", "to", "for", "of", "with", "by"].contains(lower) &&
                   keyword.count > 1
        }
        
        // Use only brand + model (2 keywords max)
        let optimizedKeywords = Array(filteredKeywords.prefix(2))
        return optimizedKeywords.joined(separator: " ")
    }
    
    // MARK: - Parse Individual eBay Item
    private func parseEbayItem(item: [String: Any]) -> EbaySoldListing? {
        
        // Extract title
        guard let titleArray = item["title"] as? [String],
              let title = titleArray.first,
              !title.isEmpty else {
            return nil
        }
        
        // Extract price
        guard let sellingStatus = item["sellingStatus"] as? [[String: Any]],
              let firstStatus = sellingStatus.first,
              let currentPrice = firstStatus["currentPrice"] as? [[String: Any]],
              let firstPrice = currentPrice.first,
              let priceValue = firstPrice["__value__"] as? String,
              let price = Double(priceValue),
              price > 0 else {
            return nil
        }
        
        // Extract end time (sold date)
        var soldDate = Date()
        if let listingInfo = item["listingInfo"] as? [[String: Any]],
           let firstListing = listingInfo.first,
           let endTimeArray = firstListing["endTime"] as? [String],
           let endTimeString = endTimeArray.first {
            
            let formatter = ISO8601DateFormatter()
            soldDate = formatter.date(from: endTimeString) ?? Date()
        }
        
        // Extract condition
        var condition = "Used"
        if let conditionArray = item["condition"] as? [[String: Any]],
           let firstCondition = conditionArray.first,
           let conditionDisplayName = firstCondition["conditionDisplayName"] as? [String],
           let conditionName = conditionDisplayName.first {
            condition = conditionName
        }
        
        // Extract shipping cost
        var shippingCost: Double? = nil
        if let shippingInfo = item["shippingInfo"] as? [[String: Any]],
           let firstShipping = shippingInfo.first,
           let shippingServiceCost = firstShipping["shippingServiceCost"] as? [[String: Any]],
           let firstCost = shippingServiceCost.first,
           let costValue = firstCost["__value__"] as? String,
           let shipping = Double(costValue) {
            shippingCost = shipping
        }
        
        // Extract listing type
        var auction = false
        if let listingInfo = item["listingInfo"] as? [[String: Any]],
           let firstListing = listingInfo.first,
           let listingType = firstListing["listingType"] as? [String],
           let type = listingType.first {
            auction = type.contains("Auction")
        }
        
        return EbaySoldListing(
            title: title,
            price: price,
            condition: condition,
            soldDate: soldDate,
            shippingCost: shippingCost,
            bestOffer: false,
            auction: auction,
            watchers: nil
        )
    }
    
    // MARK: - Price Analysis from Sold Comps
    func analyzeComps(_ soldListings: [EbaySoldListing]) -> CompAnalysis {
        guard !soldListings.isEmpty else {
            return CompAnalysis(
                averagePrice: 0,
                medianPrice: 0,
                lowPrice: 0,
                highPrice: 0,
                totalSales: 0,
                averageDaysToSell: 0,
                priceDistribution: [:],
                conditionBreakdown: [:]
            )
        }
        
        let prices = soldListings.map { $0.price }
        let sortedPrices = prices.sorted()
        
        let averagePrice = prices.reduce(0, +) / Double(prices.count)
        let medianPrice = sortedPrices.count % 2 == 0 ?
            (sortedPrices[sortedPrices.count/2 - 1] + sortedPrices[sortedPrices.count/2]) / 2 :
            sortedPrices[sortedPrices.count/2]
        
        let lowPrice = sortedPrices.first ?? 0
        let highPrice = sortedPrices.last ?? 0
        
        // Calculate average days to sell
        let now = Date()
        let daysToSell = soldListings.map { Calendar.current.dateComponents([.day], from: $0.soldDate, to: now).day ?? 0 }
        let averageDaysToSell = daysToSell.isEmpty ? 0 : Double(daysToSell.reduce(0, +)) / Double(daysToSell.count)
        
        // Price distribution (by $10 ranges)
        var priceDistribution: [String: Int] = [:]
        for price in prices {
            let range = Int(price / 10) * 10
            let key = "$\(range)-\(range + 9)"
            priceDistribution[key, default: 0] += 1
        }
        
        // Condition breakdown
        var conditionBreakdown: [String: Int] = [:]
        for listing in soldListings {
            conditionBreakdown[listing.condition, default: 0] += 1
        }
        
        return CompAnalysis(
            averagePrice: averagePrice,
            medianPrice: medianPrice,
            lowPrice: lowPrice,
            highPrice: highPrice,
            totalSales: soldListings.count,
            averageDaysToSell: averageDaysToSell,
            priceDistribution: priceDistribution,
            conditionBreakdown: conditionBreakdown
        )
    }
    
    // MARK: - Get Pricing Recommendations from Comps
    func getPricingFromComps(_ soldListings: [EbaySoldListing], condition: EbayCondition) -> EbayPricingRecommendation {
        let analysis = analyzeComps(soldListings)
        
        // Adjust pricing based on condition
        let conditionMultiplier = condition.priceMultiplier
        let basePrice = analysis.averagePrice * conditionMultiplier
        
        let recommendedPrice = basePrice
        let quickSalePrice = basePrice * 0.90
        let maxProfitPrice = basePrice * 1.15
        let competitivePrice = analysis.medianPrice * conditionMultiplier
        
        return EbayPricingRecommendation(
            recommendedPrice: recommendedPrice,
            priceRange: (min: analysis.lowPrice * conditionMultiplier, max: analysis.highPrice * conditionMultiplier),
            competitivePrice: competitivePrice,
            quickSalePrice: quickSalePrice,
            maxProfitPrice: maxProfitPrice,
            pricingStrategy: .competitive,
            priceJustification: [
                "Based on \(analysis.totalSales) recent eBay sales",
                "Average price: $\(String(format: "%.2f", analysis.averagePrice))",
                "Median price: $\(String(format: "%.2f", analysis.medianPrice))",
                "Adjusted for \(condition.rawValue) condition"
            ]
        )
    }
    
    // MARK: - eBay Listing Creation (Mock for now)
    func createListing(item: InventoryItem, analysis: AnalysisResult, completion: @escaping (EbayListingResult) -> Void) {
        isListing = true
        
        // Mock result - real implementation would use eBay Trading API
        let result = EbayListingResult(
            success: true,
            listingId: "MOCK-\(UUID().uuidString.prefix(8))",
            listingURL: "https://www.ebay.com/itm/mockitem",
            error: nil
        )
        
        print("🏪 Mock eBay listing created for: \(item.name)")
        print("  • Title: \(analysis.ebayTitle)")
        print("  • Price: $\(String(format: "%.2f", analysis.realisticPrice))")
        print("  • Condition: \(analysis.ebayCondition.rawValue)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isListing = false
            completion(result)
        }
    }
    
    // MARK: - Service Health Check
    func performHealthCheck() -> EbayServiceHealthStatus {
        let ebayConfigured = !Configuration.ebayAPIKey.isEmpty
        let serviceWorking = !isSearching || !isListing
        let rateLimitHealthy = consecutiveRateLimitErrors < 3
        
        return EbayServiceHealthStatus(
            ebayConfigured: ebayConfigured,
            listingWorking: serviceWorking && rateLimitHealthy,
            overallHealthy: ebayConfigured && serviceWorking && rateLimitHealthy,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Rate Limit Status
    func getRateLimitStatus() -> String {
        if consecutiveRateLimitErrors == 0 {
            return "✅ eBay API healthy"
        } else {
            return "⚠️ \(consecutiveRateLimitErrors) consecutive eBay API errors"
        }
    }
    
    func resetRateLimitStatus() {
        consecutiveRateLimitErrors = 0
        print("🔄 eBay API status reset")
    }
}

// MARK: - Comp Analysis Data Structure
struct CompAnalysis {
    let averagePrice: Double
    let medianPrice: Double
    let lowPrice: Double
    let highPrice: Double
    let totalSales: Int
    let averageDaysToSell: Double
    let priceDistribution: [String: Int]
    let conditionBreakdown: [String: Int]
    
    var priceRange: Double {
        return highPrice - lowPrice
    }
    
    var priceVolatility: Double {
        guard averagePrice > 0 else { return 0 }
        return priceRange / averagePrice
    }
    
    var demandLevel: String {
        switch averageDaysToSell {
        case 0...7: return "High"
        case 8...21: return "Medium"
        default: return "Low"
        }
    }
    
    var marketConfidence: Double {
        switch totalSales {
        case 20...: return 0.9
        case 10...19: return 0.8
        case 5...9: return 0.7
        case 1...4: return 0.6
        default: return 0.3
        }
    }
}
