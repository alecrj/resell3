//
//  EbayAPIService.swift
//  ResellAI
//
//  Real eBay API Service with Sold Comp Lookup
//

import SwiftUI
import Foundation

// MARK: - Real eBay API Service for Sold Comps
class EbayAPIService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authStatus = "Not authenticated"
    @Published var isSearching = false
    @Published var isListing = false
    
    private let baseURL = "https://svcs.ebay.com/services/search/FindingService/v1"
    private let browseURL = "https://api.ebay.com/buy/browse/v1"
    
    // Rate limiting
    private var lastAPICall: Date = Date(timeIntervalSince1970: 0)
    private let minAPIInterval: TimeInterval = 0.2 // 5 calls per second max
    
    init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    private func checkAuthenticationStatus() {
        // For Finding API, we just need the App ID - no OAuth required
        isAuthenticated = !Configuration.ebayAPIKey.isEmpty
        authStatus = isAuthenticated ? "Ready" : "eBay API Key missing"
    }
    
    // MARK: - Real eBay Sold Comp Lookup
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
        
        isSearching = true
        
        // Create search query from keywords
        let searchQuery = keywords.prefix(5).joined(separator: " ")
        print("🔍 Searching eBay sold comps for: \(searchQuery)")
        
        // Use eBay Finding API to get completed/sold items
        searchCompletedItems(query: searchQuery) { [weak self] results in
            DispatchQueue.main.async {
                self?.isSearching = false
                completion(results)
            }
        }
    }
    
    // MARK: - eBay Finding API - Completed Items Search
    private func searchCompletedItems(
        query: String,
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        guard let url = URL(string: baseURL) else {
            print("❌ Invalid eBay Finding API URL")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Calculate date range - last 30 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let dateFormatter = ISO8601DateFormatter()
        let endDateString = dateFormatter.string(from: endDate)
        let startDateString = dateFormatter.string(from: startDate)
        
        // Build eBay Finding API request
        let requestBody = [
            "OPERATION-NAME": "findCompletedItems",
            "SERVICE-VERSION": "1.0.0",
            "SECURITY-APPNAME": Configuration.ebayAPIKey,
            "RESPONSE-DATA-FORMAT": "JSON",
            "REST-PAYLOAD": "",
            "keywords": query,
            "itemFilter(0).name": "SoldItemsOnly",
            "itemFilter(0).value": "true",
            "itemFilter(1).name": "EndTimeFrom",
            "itemFilter(1).value": startDateString,
            "itemFilter(2).name": "EndTimeTo",
            "itemFilter(2).value": endDateString,
            "itemFilter(3).name": "ListingType",
            "itemFilter(3).value(0)": "FixedPrice",
            "itemFilter(3).value(1)": "Auction",
            "paginationInput.entriesPerPage": "100",
            "sortOrder": "EndTimeSoonest"
        ]
        
        let bodyString = requestBody
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🌐 Making eBay Finding API call for: \(query)")
        
        rateLimitedRequest(request) { [weak self] data, response, error in
            if let error = error {
                print("❌ eBay Finding API error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("❌ No data received from eBay Finding API")
                completion([])
                return
            }
            
            // Parse eBay Finding API response
            self?.parseEbayFindingResponse(data: data, completion: completion)
        }
    }
    
    // MARK: - Parse eBay Finding API Response
    private func parseEbayFindingResponse(
        data: Data,
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let findCompletedItemsResponse = jsonResponse?["findCompletedItemsResponse"] as? [[String: Any]],
                  let firstResponse = findCompletedItemsResponse.first,
                  let searchResult = firstResponse["searchResult"] as? [[String: Any]],
                  let firstResult = searchResult.first,
                  let items = firstResult["item"] as? [[String: Any]] else {
                print("❌ Invalid eBay Finding API response structure")
                completion([])
                return
            }
            
            print("✅ Found \(items.count) sold items from eBay")
            
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
            
            print("✅ Filtered to \(recentSoldListings.count) recent sold items (last 30 days)")
            
            completion(recentSoldListings)
            
        } catch {
            print("❌ Error parsing eBay Finding API response: \(error)")
            completion([])
        }
    }
    
    // MARK: - Parse Individual eBay Item
    private func parseEbayItem(item: [String: Any]) -> EbaySoldListing? {
        
        // Extract title
        guard let titleArray = item["title"] as? [String],
              let title = titleArray.first else {
            return nil
        }
        
        // Extract price
        guard let sellingStatus = item["sellingStatus"] as? [[String: Any]],
              let firstStatus = sellingStatus.first,
              let currentPrice = firstStatus["currentPrice"] as? [[String: Any]],
              let firstPrice = currentPrice.first,
              let priceValue = firstPrice["__value__"] as? String,
              let price = Double(priceValue) else {
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
    
    // MARK: - Alternative Search with Different Keywords
    func searchWithMultipleQueries(
        keywordSets: [[String]],
        completion: @escaping ([EbaySoldListing]) -> Void
    ) {
        
        var allResults: [EbaySoldListing] = []
        let group = DispatchGroup()
        
        // Search with up to 3 different keyword combinations
        for keywords in keywordSets.prefix(3) {
            group.enter()
            
            getSoldComps(keywords: keywords) { results in
                allResults.append(contentsOf: results)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Remove duplicates based on title and price
            let uniqueResults = self.removeDuplicates(from: allResults)
            completion(uniqueResults)
        }
    }
    
    // MARK: - Remove Duplicate Listings
    private func removeDuplicates(from listings: [EbaySoldListing]) -> [EbaySoldListing] {
        var uniqueListings: [EbaySoldListing] = []
        var seenSignatures: Set<String> = []
        
        for listing in listings {
            // Create signature from title + price
            let signature = "\(listing.title.lowercased().prefix(50))-\(String(format: "%.2f", listing.price))"
            
            if !seenSignatures.contains(signature) {
                seenSignatures.insert(signature)
                uniqueListings.append(listing)
            }
        }
        
        return uniqueListings.sorted { $0.soldDate > $1.soldDate }
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
                "Based on \(analysis.totalSales) recent sales",
                "Average price: $\(String(format: "%.2f", analysis.averagePrice))",
                "Median price: $\(String(format: "%.2f", analysis.medianPrice))",
                "Adjusted for \(condition.rawValue) condition"
            ]
        )
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
    
    // MARK: - Service Health Check
    func performHealthCheck() -> EbayServiceHealthStatus {
        let ebayConfigured = !Configuration.ebayAPIKey.isEmpty
        let serviceWorking = !isSearching || !isListing
        
        return EbayServiceHealthStatus(
            ebayConfigured: ebayConfigured,
            listingWorking: serviceWorking,
            overallHealthy: ebayConfigured && serviceWorking,
            lastUpdated: Date()
        )
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

// MARK: - Service Health Check Implementation
// Note: EbayServiceHealthStatus is defined in AlService.swift
