//
//  MarketDataService.swift
//  ResellAI
//
//  Created by Alec on 8/3/25.
//


//
//  MarketDataService.swift
//  ResellAI
//
//  Complete Market Data Service with All Methods
//

import Foundation
import UIKit

class MarketDataService: ObservableObject {
    @Published var isSearching = false
    @Published var searchProgress = "Ready"
    
    private let ebayAPIKey = Configuration.ebayAPIKey
    private let rapidAPIKey = Configuration.rapidAPIKey
    
    init() {
        print("📊 Market Data Service initialized")
        validateConfiguration()
    }
    
    private func validateConfiguration() {
        if ebayAPIKey.isEmpty {
            print("❌ eBay API key missing!")
        } else {
            print("✅ eBay API key configured")
        }
        
        if rapidAPIKey.isEmpty {
            print("❌ RapidAPI key missing!")
        } else {
            print("✅ RapidAPI key configured")
        }
    }
    
    // MARK: - Main Market Data Search (Added missing method)
    func getMarketData(for productName: String, completion: @escaping (MarketData?) -> Void) {
        searchMarketData(for: productName, completion: completion)
    }
    
    // MARK: - Search Market Data
    func searchMarketData(for productName: String, completion: @escaping (MarketData?) -> Void) {
        guard !productName.isEmpty else {
            completion(nil)
            return
        }
        
        isSearching = true
        searchProgress = "Searching eBay sold listings..."
        
        // First try eBay Finding API
        searchEbaySoldListings(query: productName) { [weak self] soldListings in
            DispatchQueue.main.async {
                self?.isSearching = false
                self?.searchProgress = "Search complete"
                
                if !soldListings.isEmpty {
                    let marketData = self?.createMarketData(from: soldListings)
                    completion(marketData)
                } else {
                    // Fallback to estimated data
                    let fallbackData = self?.createFallbackMarketData(for: productName)
                    completion(fallbackData)
                }
            }
        }
    }
    
    // MARK: - eBay Sold Listings Search
    private func searchEbaySoldListings(query: String, completion: @escaping ([EbaySoldListing]) -> Void) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = """
        \(Configuration.ebayFindingAPIBase)?OPERATION-NAME=findCompletedItems&SERVICE-VERSION=1.0.0&SECURITY-APPNAME=\(ebayAPIKey)&RESPONSE-DATA-FORMAT=JSON&REST-PAYLOAD&keywords=\(encodedQuery)&itemFilter(0).name=SoldItemsOnly&itemFilter(0).value=true&itemFilter(1).name=ListingType&itemFilter(1).value(0)=FixedPrice&itemFilter(1).value(1)=Auction&sortOrder=EndTimeSoonest&paginationInput.entriesPerPage=25
        """
        
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ eBay API error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                completion([])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let response = json["findCompletedItemsResponse"] as? [[String: Any]],
                   let firstResponse = response.first,
                   let searchResult = firstResponse["searchResult"] as? [[String: Any]],
                   let firstResult = searchResult.first,
                   let items = firstResult["item"] as? [[String: Any]] {
                    
                    let soldListings = self?.parseEbayResponse(items) ?? []
                    completion(soldListings)
                } else {
                    print("⚠️ eBay API returned no results for: \(query)")
                    completion([])
                }
            } catch {
                print("❌ Error parsing eBay response: \(error)")
                completion([])
            }
        }.resume()
    }
    
    // MARK: - Parse eBay Response
    private func parseEbayResponse(_ items: [[String: Any]]) -> [EbaySoldListing] {
        var soldListings: [EbaySoldListing] = []
        
        for item in items {
            if let title = (item["title"] as? [String])?.first,
               let sellingStatus = (item["sellingStatus"] as? [[String: Any]])?.first,
               let priceInfo = (sellingStatus["currentPrice"] as? [[String: Any]])?.first,
               let priceString = priceInfo["__value__"] as? String,
               let price = Double(priceString) {
                
                let conditionInfo = (item["condition"] as? [[String: Any]])?.first
                let conditionName = (conditionInfo?["conditionDisplayName"] as? [String])?.first ?? "Used"
                
                let shippingInfo = (item["shippingInfo"] as? [[String: Any]])?.first
                let shippingCostInfo = (shippingInfo?["shippingServiceCost"] as? [[String: Any]])?.first
                let shippingCostString = shippingCostInfo?["__value__"] as? String
                let shippingCost = shippingCostString != nil ? Double(shippingCostString!) : nil
                
                let listingInfo = (item["listingInfo"] as? [[String: Any]])?.first
                let endTimeString = (listingInfo?["endTime"] as? [String])?.first
                
                let soldDate: Date
                if let endTimeString = endTimeString {
                    let formatter = ISO8601DateFormatter()
                    soldDate = formatter.date(from: endTimeString) ?? Date()
                } else {
                    soldDate = Date()
                }
                
                let soldListing = EbaySoldListing(
                    title: title,
                    price: price,
                    condition: conditionName,
                    soldDate: soldDate,
                    shippingCost: shippingCost,
                    watchers: nil,
                    bids: nil,
                    seller: nil,
                    location: nil,
                    itemId: (item["itemId"] as? [String])?.first
                )
                
                soldListings.append(soldListing)
            }
        }
        
        print("📊 Parsed \(soldListings.count) sold listings from eBay")
        return soldListings
    }
    
    // MARK: - Create Market Data from Listings
    private func createMarketData(from soldListings: [EbaySoldListing]) -> MarketData {
        let prices = soldListings.map { $0.price }
        let averagePrice = prices.reduce(0, +) / Double(prices.count)
        
        let sortedPrices = prices.sorted()
        let lowest = sortedPrices.first ?? 0
        let highest = sortedPrices.last ?? 0
        let median = sortedPrices.count > 0 ? sortedPrices[sortedPrices.count / 2] : 0
        
        let priceRange = EbayPriceRange(
            lowest: lowest,
            highest: highest,
            average: averagePrice,
            median: median,
            sampleSize: prices.count
        )
        
        let demandIndicators = generateDemandIndicators(from: soldListings)
        
        return MarketData(
            averagePrice: averagePrice,
            priceRange: priceRange,
            soldListings: soldListings,
            totalSold: soldListings.count,
            averageDaysToSell: calculateAverageDaysToSell(soldListings),
            seasonalTrends: nil,
            competitorAnalysis: "Based on \(soldListings.count) recent sales",
            demandIndicators: demandIndicators,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Create Fallback Market Data
    private func createFallbackMarketData(for productName: String) -> MarketData {
        // Estimate price based on product type
        let estimatedPrice = estimatePrice(for: productName)
        
        let priceRange = EbayPriceRange(
            lowest: estimatedPrice * 0.6,
            highest: estimatedPrice * 1.4,
            average: estimatedPrice,
            median: estimatedPrice,
            sampleSize: 0
        )
        
        return MarketData(
            averagePrice: estimatedPrice,
            priceRange: priceRange,
            soldListings: [],
            totalSold: 0,
            averageDaysToSell: nil,
            seasonalTrends: nil,
            competitorAnalysis: "No recent sales data available",
            demandIndicators: ["Limited market data"],
            lastUpdated: Date()
        )
    }
    
    // MARK: - Helper Functions
    private func estimatePrice(for productName: String) -> Double {
        let lowercased = productName.lowercased()
        
        if lowercased.contains("nike") || lowercased.contains("jordan") {
            return 120.0
        } else if lowercased.contains("adidas") {
            return 90.0
        } else if lowercased.contains("shirt") || lowercased.contains("tee") {
            return 25.0
        } else if lowercased.contains("jacket") || lowercased.contains("coat") {
            return 60.0
        } else if lowercased.contains("jeans") || lowercased.contains("pants") {
            return 40.0
        } else if lowercased.contains("electronics") || lowercased.contains("phone") {
            return 200.0
        } else if lowercased.contains("book") {
            return 15.0
        } else if lowercased.contains("toy") || lowercased.contains("game") {
            return 30.0
        } else {
            return 35.0
        }
    }
    
    private func generateDemandIndicators(from soldListings: [EbaySoldListing]) -> [String] {
        var indicators: [String] = []
        
        let recentSales = soldListings.filter { 
            $0.soldDate >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date() 
        }.count
        
        if recentSales > 20 {
            indicators.append("High demand - \(recentSales) sales in 30 days")
        } else if recentSales > 10 {
            indicators.append("Moderate demand - \(recentSales) sales in 30 days")
        } else if recentSales > 0 {
            indicators.append("Low demand - \(recentSales) sales in 30 days")
        } else {
            indicators.append("Limited sales data available")
        }
        
        // Price consistency
        let prices = soldListings.map { $0.price }
        if prices.count > 1 {
            let averagePrice = prices.reduce(0, +) / Double(prices.count)
            let variance = prices.map { pow($0 - averagePrice, 2) }.reduce(0, +) / Double(prices.count)
            let coefficient = averagePrice > 0 ? sqrt(variance) / averagePrice : 0
            
            if coefficient < 0.2 {
                indicators.append("Stable pricing")
            } else if coefficient < 0.4 {
                indicators.append("Moderate price variation")
            } else {
                indicators.append("High price variation")
            }
        }
        
        return indicators
    }
    
    private func calculateAverageDaysToSell(_ soldListings: [EbaySoldListing]) -> Double? {
        // This would require listing start dates, which aren't available in sold listings
        // Return nil for now
        return nil
    }
    
    // MARK: - Market Analysis
    func analyzeMarket(for productName: String, completion: @escaping (MarketAnalysisResult?) -> Void) {
        searchMarketData(for: productName) { marketData in
            guard let marketData = marketData else {
                completion(nil)
                return
            }
            
            let intelligence = MarketIntelligence(
                averagePrice: marketData.averagePrice,
                priceRange: marketData.priceRange,
                salesVelocity: Double(marketData.soldInLast30Days),
                competitionLevel: .moderate
            )
            
            let analysisResult = MarketAnalysisResult(intelligence: intelligence)
            completion(analysisResult)
        }
    }
    
    // MARK: - Utility Functions
    func reset() {
        isSearching = false
        searchProgress = "Ready"
    }
}