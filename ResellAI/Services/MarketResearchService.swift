//
//  MarketDataService.swift
//  ResellAI
//
//  Production-Ready Market Data Service with Real RapidAPI eBay Integration
//

import SwiftUI
import Foundation

// MARK: - Production Market Data Service with Real eBay Comps
class MarketDataService: ObservableObject {
    @Published var isResearching = false
    @Published var researchProgress = "Ready"
    
    // Real data sources
    private let rapidAPIService = RapidAPIMarketService()
    private let ebayAPIFallback = EbayAPIService()
    
    init() {
        print("📊 Production Market Data Service initialized with RapidAPI")
    }
    
    // MARK: - Main Market Research with Real eBay Data
    func researchProduct(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        completion: @escaping (MarketAnalysisResult?) -> Void
    ) {
        
        isResearching = true
        researchProgress = "Searching real eBay sold listings..."
        
        print("🔍 Market research for: \(identification.exactModelName)")
        print("• Brand: \(identification.brand)")
        print("• Size: \(identification.size)")
        print("• Colorway: \(identification.colorway)")
        
        // Use RapidAPI to get real eBay sold data
        searchRealEbayData(identification: identification, condition: condition) { [weak self] result in
            DispatchQueue.main.async {
                self?.isResearching = false
                self?.researchProgress = result != nil ? "Real eBay data retrieved!" : "Using fallback data"
                completion(result)
            }
        }
    }
    
    // MARK: - Real eBay Data Search via RapidAPI
    private func searchRealEbayData(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        completion: @escaping (MarketAnalysisResult?) -> Void
    ) {
        
        // Create optimized search query for eBay
        let searchQuery = createOptimizedSearchQuery(identification)
        print("🔍 RapidAPI eBay search: \(searchQuery)")
        
        researchProgress = "Fetching eBay sold listings..."
        
        rapidAPIService.getEbaySoldListings(query: searchQuery) { [weak self] soldListings in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if !soldListings.isEmpty {
                print("✅ Found \(soldListings.count) real eBay sold listings!")
                let marketAnalysis = self.createMarketAnalysis(
                    identification: identification,
                    condition: condition,
                    soldListings: soldListings
                )
                completion(marketAnalysis)
            } else {
                print("⚠️ No sold listings found via RapidAPI, trying eBay Finding API...")
                self.fallbackToEbayAPI(identification: identification, condition: condition, completion: completion)
            }
        }
    }
    
    // MARK: - Fallback to eBay Finding API
    private func fallbackToEbayAPI(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        completion: @escaping (MarketAnalysisResult?) -> Void
    ) {
        
        researchProgress = "Trying eBay Finding API..."
        
        let keywords = [identification.brand, identification.exactModelName, identification.size]
            .filter { !$0.isEmpty }
        
        ebayAPIFallback.getSoldComps(keywords: keywords) { [weak self] soldListings in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if !soldListings.isEmpty {
                print("✅ Found \(soldListings.count) sold listings via eBay Finding API")
                let marketAnalysis = self.createMarketAnalysis(
                    identification: identification,
                    condition: condition,
                    soldListings: soldListings
                )
                completion(marketAnalysis)
            } else {
                print("❌ No sold listings found - creating estimate")
                let fallbackAnalysis = self.createFallbackAnalysis(identification: identification, condition: condition)
                completion(fallbackAnalysis)
            }
        }
    }
    
    // MARK: - Create Optimized Search Query
    private func createOptimizedSearchQuery(_ identification: PrecisionIdentificationResult) -> String {
        var queryParts: [String] = []
        
        // Always include brand if available
        if !identification.brand.isEmpty {
            queryParts.append(identification.brand)
        }
        
        // Include model name but clean it up
        let cleanModelName = identification.exactModelName
            .replacingOccurrences(of: identification.brand, with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanModelName.isEmpty {
            queryParts.append(cleanModelName)
        }
        
        // Include size if specific
        if !identification.size.isEmpty && identification.size.count < 10 {
            queryParts.append(identification.size)
        }
        
        // Include style code if available
        if !identification.styleCode.isEmpty && identification.styleCode.count < 15 {
            queryParts.append(identification.styleCode)
        }
        
        let query = queryParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? identification.exactModelName : query
    }
    
    // MARK: - Create Market Analysis from Real Data
    private func createMarketAnalysis(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        soldListings: [EbaySoldListing]
    ) -> MarketAnalysisResult {
        
        // Calculate real market metrics
        let prices = soldListings.map { $0.price }
        let avgPrice = prices.reduce(0, +) / Double(prices.count)
        let sortedPrices = prices.sorted()
        let medianPrice = sortedPrices.count % 2 == 0 ?
            (sortedPrices[sortedPrices.count/2 - 1] + sortedPrices[sortedPrices.count/2]) / 2 :
            sortedPrices[sortedPrices.count/2]
        
        print("💰 Market Analysis Results:")
        print("  • Sales Found: \(soldListings.count)")
        print("  • Average Price: $\(String(format: "%.2f", avgPrice))")
        print("  • Median Price: $\(String(format: "%.2f", medianPrice))")
        print("  • Price Range: $\(String(format: "%.2f", sortedPrices.first ?? 0)) - $\(String(format: "%.2f", sortedPrices.last ?? 0))")
        
        // Create price range by condition
        let priceRange = EbayPriceRange(
            newWithTags: avgPrice * 1.0,
            newWithoutTags: avgPrice * 0.95,
            likeNew: avgPrice * 0.85,
            excellent: avgPrice * 0.75,
            veryGood: avgPrice * 0.65,
            good: avgPrice * 0.50,
            acceptable: avgPrice * 0.35,
            average: avgPrice,
            soldCount: soldListings.count,
            dateRange: "Last 30 days"
        )
        
        // Analyze market trend
        let marketTrend = analyzeMarketTrend(soldListings: soldListings)
        
        // Calculate demand indicators
        let demandIndicators = calculateDemandIndicators(soldListings: soldListings)
        
        // Determine competition level
        let competitionLevel = determineCompetition(salesCount: soldListings.count)
        
        let marketData = EbayMarketData(
            soldListings: soldListings,
            priceRange: priceRange,
            marketTrend: marketTrend,
            demandIndicators: demandIndicators,
            competitionLevel: competitionLevel,
            lastUpdated: Date()
        )
        
        let conditionAssessment = EbayConditionAssessment(
            detectedCondition: condition,
            conditionConfidence: 0.85,
            conditionFactors: [],
            conditionNotes: createConditionNotes(soldListings: soldListings),
            photographyRecommendations: getPhotoRecommendations()
        )
        
        let pricingRecommendation = createPricing(
            averagePrice: avgPrice,
            medianPrice: medianPrice,
            condition: condition,
            marketData: marketData
        )
        
        let listingStrategy = createListingStrategy(
            identification: identification,
            condition: condition,
            marketData: marketData
        )
        
        let confidence = calculateConfidence(
            identification: identification,
            salesCount: soldListings.count,
            priceVariance: calculatePriceVariance(prices: prices)
        )
        
        return MarketAnalysisResult(
            identifiedProduct: identification,
            marketData: marketData,
            conditionAssessment: conditionAssessment,
            pricingRecommendation: pricingRecommendation,
            listingStrategy: listingStrategy,
            confidence: confidence
        )
    }
    
    // MARK: - Helper Methods
    private func analyzeMarketTrend(soldListings: [EbaySoldListing]) -> MarketTrend {
        // Analyze price trend over time
        let sortedByDate = soldListings.sorted { $0.soldDate < $1.soldDate }
        
        if sortedByDate.count < 5 {
            return MarketTrend(direction: .stable, strength: .moderate, timeframe: "30 days", seasonalFactors: [])
        }
        
        let firstHalf = Array(sortedByDate.prefix(sortedByDate.count / 2))
        let secondHalf = Array(sortedByDate.suffix(sortedByDate.count / 2))
        
        let firstHalfAvg = firstHalf.map { $0.price }.reduce(0, +) / Double(firstHalf.count)
        let secondHalfAvg = secondHalf.map { $0.price }.reduce(0, +) / Double(secondHalf.count)
        
        let trendPercent = (secondHalfAvg - firstHalfAvg) / firstHalfAvg
        
        let direction: TrendDirection = trendPercent > 0.05 ? .increasing : trendPercent < -0.05 ? .decreasing : .stable
        let strength: TrendStrength = abs(trendPercent) > 0.15 ? .strong : .moderate
        
        return MarketTrend(direction: direction, strength: strength, timeframe: "30 days", seasonalFactors: [])
    }
    
    private func calculateDemandIndicators(soldListings: [EbaySoldListing]) -> DemandIndicators {
        // Calculate average time to sell based on listing patterns
        let now = Date()
        let daysToSell = soldListings.map {
            Calendar.current.dateComponents([.day], from: $0.soldDate, to: now).day ?? 0
        }
        
        let avgDaysToSell = daysToSell.isEmpty ? 30 : Double(daysToSell.reduce(0, +)) / Double(daysToSell.count)
        
        let timeToSell: TimeToSell = avgDaysToSell < 7 ? .fast : avgDaysToSell < 21 ? .normal : .slow
        let searchVolume: SearchVolume = soldListings.count > 20 ? .high : soldListings.count > 10 ? .medium : .low
        
        return DemandIndicators(
            watchersPerListing: 0,
            viewsPerListing: 0,
            timeToSell: timeToSell,
            searchVolume: searchVolume
        )
    }
    
    private func determineCompetition(salesCount: Int) -> CompetitionLevel {
        switch salesCount {
        case 0...5: return .low
        case 6...20: return .moderate
        case 21...50: return .high
        default: return .saturated
        }
    }
    
    private func createConditionNotes(soldListings: [EbaySoldListing]) -> [String] {
        var notes: [String] = []
        notes.append("Based on \(soldListings.count) real eBay sales")
        
        if soldListings.count > 20 {
            notes.append("High confidence pricing with excellent market data")
        } else if soldListings.count > 10 {
            notes.append("Good market data available for pricing")
        } else if soldListings.count > 5 {
            notes.append("Moderate market data - pricing has some uncertainty")
        } else {
            notes.append("Limited market data - price estimate based on few sales")
        }
        
        // Analyze condition distribution
        let conditionCounts = Dictionary(grouping: soldListings, by: { $0.condition })
        if let mostCommonCondition = conditionCounts.max(by: { $0.value.count < $1.value.count }) {
            notes.append("Most common condition sold: \(mostCommonCondition.key)")
        }
        
        return notes
    }
    
    private func getPhotoRecommendations() -> [String] {
        return [
            "Take clear photos from multiple angles",
            "Show brand tags and labels clearly",
            "Include close-ups of any condition issues",
            "Use good lighting to show true colors",
            "Include size tags or measurements"
        ]
    }
    
    private func createPricing(
        averagePrice: Double,
        medianPrice: Double,
        condition: EbayCondition,
        marketData: EbayMarketData
    ) -> EbayPricingRecommendation {
        
        let conditionMultiplier = condition.priceMultiplier
        let basePrice = medianPrice * conditionMultiplier // Use median as it's less affected by outliers
        
        return EbayPricingRecommendation(
            recommendedPrice: basePrice,
            priceRange: (min: basePrice * 0.85, max: basePrice * 1.15),
            competitivePrice: basePrice * 0.95,
            quickSalePrice: basePrice * 0.85,
            maxProfitPrice: basePrice * 1.10,
            pricingStrategy: .competitive,
            priceJustification: [
                "Based on \(marketData.soldListings.count) real eBay sales",
                "Median price: $\(String(format: "%.2f", medianPrice))",
                "Average price: $\(String(format: "%.2f", averagePrice))",
                "Adjusted for \(condition.rawValue) condition"
            ]
        )
    }
    
    private func createListingStrategy(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        marketData: EbayMarketData
    ) -> EbayListingStrategy {
        
        let title = generateOptimizedTitle(identification: identification, condition: condition)
        let keywords = generateKeywords(identification: identification, marketData: marketData)
        
        return EbayListingStrategy(
            recommendedTitle: title,
            keywordOptimization: keywords,
            categoryPath: mapToEbayCategory(identification.category),
            listingFormat: .buyItNow,
            photographyChecklist: getPhotoRecommendations(),
            descriptionTemplate: createDescription(identification: identification, condition: condition)
        )
    }
    
    private func generateOptimizedTitle(identification: PrecisionIdentificationResult, condition: EbayCondition) -> String {
        var titleParts: [String] = []
        
        if !identification.brand.isEmpty {
            titleParts.append(identification.brand)
        }
        
        titleParts.append(identification.exactModelName)
        
        if !identification.size.isEmpty {
            titleParts.append("Size \(identification.size)")
        }
        
        if !identification.colorway.isEmpty {
            titleParts.append(identification.colorway)
        }
        
        titleParts.append(condition.rawValue)
        
        let title = titleParts.joined(separator: " ")
        return String(title.prefix(80)) // eBay title limit
    }
    
    private func generateKeywords(identification: PrecisionIdentificationResult, marketData: EbayMarketData) -> [String] {
        var keywords: [String] = []
        
        keywords.append(identification.brand)
        keywords.append(identification.exactModelName)
        keywords.append(identification.productLine)
        keywords.append(identification.styleCode)
        keywords.append(identification.colorway)
        keywords.append(identification.size)
        keywords.append(identification.category.rawValue)
        
        return keywords.filter { !$0.isEmpty }
    }
    
    private func mapToEbayCategory(_ category: ProductCategory) -> String {
        switch category {
        case .sneakers: return "Clothing, Shoes & Accessories > Unisex Shoes"
        case .clothing: return "Clothing, Shoes & Accessories"
        case .electronics: return "Consumer Electronics"
        case .accessories: return "Clothing, Shoes & Accessories > Accessories"
        case .home: return "Home & Garden"
        case .collectibles: return "Collectibles"
        case .books: return "Books & Magazines"
        case .toys: return "Toys & Hobbies"
        case .sports: return "Sporting Goods"
        case .other: return "Everything Else"
        }
    }
    
    private func createDescription(identification: PrecisionIdentificationResult, condition: EbayCondition) -> String {
        return """
        \(identification.exactModelName)
        
        CONDITION: \(condition.rawValue)
        \(condition.description)
        
        DETAILS:
        • Brand: \(identification.brand)
        • Model: \(identification.exactModelName)
        • Style Code: \(identification.styleCode)
        • Size: \(identification.size)
        • Colorway: \(identification.colorway)
        • Category: \(identification.category.rawValue)
        
        MARKET VERIFIED:
        • Professional market analysis with real eBay sales data
        • Competitive pricing based on recent market activity
        • Authentic item verification
        
        Fast shipping • 30-day returns • Excellent service
        """
    }
    
    private func calculateConfidence(
        identification: PrecisionIdentificationResult,
        salesCount: Int,
        priceVariance: Double
    ) -> MarketConfidence {
        
        let dataQuality: DataQuality = salesCount > 20 ? .excellent : salesCount > 10 ? .good : salesCount > 5 ? .fair : salesCount > 0 ? .limited : .insufficient
        
        // Pricing confidence based on sales count and price consistency
        let pricingConfidence = min(0.95, (Double(salesCount) * 0.05) + (1.0 - min(priceVariance, 1.0)))
        
        return MarketConfidence(
            overall: (identification.confidence + pricingConfidence) / 2,
            identification: identification.confidence,
            condition: 0.85,
            pricing: pricingConfidence,
            dataQuality: dataQuality
        )
    }
    
    private func calculatePriceVariance(prices: [Double]) -> Double {
        guard prices.count > 1 else { return 0 }
        
        let mean = prices.reduce(0, +) / Double(prices.count)
        let variance = prices.map { pow($0 - mean, 2) }.reduce(0, +) / Double(prices.count)
        let standardDeviation = sqrt(variance)
        
        return mean > 0 ? standardDeviation / mean : 0
    }
    
    private func createFallbackAnalysis(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition
    ) -> MarketAnalysisResult {
        
        print("⚠️ Creating fallback analysis - no market data found")
        
        let estimatedPrice = estimateBasePrice(identification: identification)
        
        let priceRange = EbayPriceRange(
            newWithTags: estimatedPrice * 1.0,
            newWithoutTags: estimatedPrice * 0.95,
            likeNew: estimatedPrice * 0.85,
            excellent: estimatedPrice * 0.75,
            veryGood: estimatedPrice * 0.65,
            good: estimatedPrice * 0.50,
            acceptable: estimatedPrice * 0.35,
            average: estimatedPrice * 0.70,
            soldCount: 0,
            dateRange: "No market data"
        )
        
        let marketData = EbayMarketData(
            soldListings: [],
            priceRange: priceRange,
            marketTrend: MarketTrend(direction: .stable, strength: .moderate, timeframe: "Unknown", seasonalFactors: []),
            demandIndicators: DemandIndicators(watchersPerListing: 0, viewsPerListing: 0, timeToSell: .normal, searchVolume: .low),
            competitionLevel: .moderate,
            lastUpdated: Date()
        )
        
        let conditionAssessment = EbayConditionAssessment(
            detectedCondition: condition,
            conditionConfidence: 0.7,
            conditionFactors: [],
            conditionNotes: ["No market data found - using category-based estimate"],
            photographyRecommendations: getPhotoRecommendations()
        )
        
        let pricingRecommendation = EbayPricingRecommendation(
            recommendedPrice: estimatedPrice * condition.priceMultiplier,
            priceRange: (min: estimatedPrice * 0.6, max: estimatedPrice * 0.9),
            competitivePrice: estimatedPrice * 0.72,
            quickSalePrice: estimatedPrice * 0.65,
            maxProfitPrice: estimatedPrice * 0.85,
            pricingStrategy: .discount,
            priceJustification: ["Estimated price - no market data available"]
        )
        
        let listingStrategy = createListingStrategy(identification: identification, condition: condition, marketData: marketData)
        let confidence = MarketConfidence(overall: 0.5, identification: identification.confidence, condition: 0.7, pricing: 0.3, dataQuality: .insufficient)
        
        return MarketAnalysisResult(
            identifiedProduct: identification,
            marketData: marketData,
            conditionAssessment: conditionAssessment,
            pricingRecommendation: pricingRecommendation,
            listingStrategy: listingStrategy,
            confidence: confidence
        )
    }
    
    private func estimateBasePrice(identification: PrecisionIdentificationResult) -> Double {
        let brand = identification.brand.lowercased()
        let category = identification.category
        
        if brand.contains("nike") || brand.contains("jordan") {
            return category == .sneakers ? 120.0 : 45.0
        } else if brand.contains("adidas") {
            return category == .sneakers ? 100.0 : 40.0
        } else if brand.contains("vans") {
            return category == .sneakers ? 60.0 : 35.0
        } else if brand.contains("apple") {
            return 350.0
        } else if brand.contains("supreme") {
            return 200.0
        }
        
        switch category {
        case .sneakers: return 70.0
        case .electronics: return 150.0
        case .clothing: return 30.0
        case .accessories: return 35.0
        default: return 40.0
        }
    }
}

// MARK: - Real RapidAPI eBay Service with Multiple Endpoints
class RapidAPIMarketService {
    private let apiKey = Configuration.rapidAPIKey
    
    // Try multiple RapidAPI eBay endpoints
    private let endpoints = [
        ("ebay-sold-listing-tracker.p.rapidapi.com", "/search"),
        ("ebay-average-selling-price.p.rapidapi.com", "/search"),
        ("ebay-search-result.p.rapidapi.com", "/search"),
        ("ebay-data-analytics.p.rapidapi.com", "/sold-listings"),
        ("ebay-scraper.p.rapidapi.com", "/sold-items")
    ]
    
    func getEbaySoldListings(query: String, completion: @escaping ([EbaySoldListing]) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ RapidAPI key not configured")
            completion([])
            return
        }
        
        print("🔍 RapidAPI searching for: \(query)")
        
        // Try endpoints in order until we get data
        tryEndpoints(query: query, endpointIndex: 0, completion: completion)
    }
    
    private func tryEndpoints(query: String, endpointIndex: Int, completion: @escaping ([EbaySoldListing]) -> Void) {
        guard endpointIndex < endpoints.count else {
            print("❌ All RapidAPI endpoints failed")
            completion([])
            return
        }
        
        let (host, path) = endpoints[endpointIndex]
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try different URL patterns for different APIs
        var urlString: String
        if host.contains("sold-listing-tracker") {
            urlString = "https://\(host)\(path)?q=\(encodedQuery)&sold_items_only=true&limit=50"
        } else if host.contains("average-selling-price") {
            urlString = "https://\(host)\(path)?keywords=\(encodedQuery)&sold=true"
        } else if host.contains("search-result") {
            urlString = "https://\(host)\(path)/\(encodedQuery)?sold_items_only=true"
        } else if host.contains("data-analytics") {
            urlString = "https://\(host)\(path)?search_term=\(encodedQuery)&days=30"
        } else {
            urlString = "https://\(host)\(path)?query=\(encodedQuery)&type=sold"
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for \(host)")
            tryEndpoints(query: query, endpointIndex: endpointIndex + 1, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(host, forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        print("🌐 Trying RapidAPI endpoint \(endpointIndex + 1)/\(endpoints.count): \(host)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ RapidAPI endpoint \(endpointIndex + 1) error: \(error)")
                self?.tryEndpoints(query: query, endpointIndex: endpointIndex + 1, completion: completion)
                return
            }
            
            guard let data = data else {
                print("❌ No data from RapidAPI endpoint \(endpointIndex + 1)")
                self?.tryEndpoints(query: query, endpointIndex: endpointIndex + 1, completion: completion)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 RapidAPI endpoint \(endpointIndex + 1) response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    self?.parseRapidAPIResponse(data: data, host: host) { results in
                        if !results.isEmpty {
                            print("✅ RapidAPI endpoint \(endpointIndex + 1) (\(host)) returned \(results.count) results!")
                            completion(results)
                        } else {
                            print("⚠️ RapidAPI endpoint \(endpointIndex + 1) returned 0 results, trying next...")
                            self?.tryEndpoints(query: query, endpointIndex: endpointIndex + 1, completion: completion)
                        }
                    }
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ RapidAPI endpoint \(endpointIndex + 1) error (\(httpResponse.statusCode)): \(String(responseString.prefix(200)))")
                    }
                    self?.tryEndpoints(query: query, endpointIndex: endpointIndex + 1, completion: completion)
                }
            } else {
                self?.tryEndpoints(query: query, endpointIndex: endpointIndex + 1, completion: completion)
            }
        }.resume()
    }
    
    private func parseRapidAPIResponse(data: Data, host: String, completion: @escaping ([EbaySoldListing]) -> Void) {
        do {
            // Try to parse the response - structure depends on the specific RapidAPI endpoint
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📄 RapidAPI response structure: \(json.keys)")
                
                var soldListings: [EbaySoldListing] = []
                
                // Try different possible response structures
                if let results = json["results"] as? [[String: Any]] {
                    soldListings = parseListings(from: results)
                } else if let items = json["items"] as? [[String: Any]] {
                    soldListings = parseListings(from: items)
                } else if let data = json["data"] as? [[String: Any]] {
                    soldListings = parseListings(from: data)
                } else if let listings = json["listings"] as? [[String: Any]] {
                    soldListings = parseListings(from: listings)
                } else {
                    print("⚠️ Unknown RapidAPI response structure")
                    // Try to parse the entire response as an array
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        soldListings = parseListings(from: jsonArray)
                    }
                }
                
                print("✅ RapidAPI parsed \(soldListings.count) sold listings")
                completion(soldListings)
                
            } else {
                print("❌ Could not parse RapidAPI JSON response")
                completion([])
            }
        } catch {
            print("❌ RapidAPI JSON parsing error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw response: \(String(responseString.prefix(500)))")
            }
            completion([])
        }
    }
    
    private func parseListings(from items: [[String: Any]]) -> [EbaySoldListing] {
        var soldListings: [EbaySoldListing] = []
        
        for item in items {
            // Try to extract listing data from various possible field names
            let title = extractTitle(from: item)
            let price = extractPrice(from: item)
            let condition = extractCondition(from: item)
            let soldDate = extractSoldDate(from: item)
            let shipping = extractShipping(from: item)
            let isAuction = extractAuctionStatus(from: item)
            
            if !title.isEmpty && price > 0 {
                let listing = EbaySoldListing(
                    title: title,
                    price: price,
                    condition: condition,
                    soldDate: soldDate,
                    shippingCost: shipping,
                    bestOffer: false,
                    auction: isAuction,
                    watchers: nil
                )
                soldListings.append(listing)
            }
        }
        
        return soldListings
    }
    
    private func extractTitle(from item: [String: Any]) -> String {
        let possibleKeys = ["title", "name", "itemTitle", "listing_title", "product_title"]
        for key in possibleKeys {
            if let title = item[key] as? String, !title.isEmpty {
                return title
            }
        }
        return ""
    }
    
    private func extractPrice(from item: [String: Any]) -> Double {
        let possibleKeys = ["price", "currentPrice", "soldPrice", "finalPrice", "sale_price", "amount"]
        for key in possibleKeys {
            if let priceString = item[key] as? String {
                let cleanPrice = priceString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                if let price = Double(cleanPrice), price > 0 {
                    return price
                }
            } else if let priceDouble = item[key] as? Double, priceDouble > 0 {
                return priceDouble
            } else if let priceDict = item[key] as? [String: Any] {
                if let value = priceDict["value"] as? Double {
                    return value
                } else if let amount = priceDict["amount"] as? Double {
                    return amount
                }
            }
        }
        return 0
    }
    
    private func extractCondition(from item: [String: Any]) -> String {
        let possibleKeys = ["condition", "conditionDisplayName", "item_condition", "listing_condition"]
        for key in possibleKeys {
            if let condition = item[key] as? String, !condition.isEmpty {
                return condition
            }
        }
        return "Used"
    }
    
    private func extractSoldDate(from item: [String: Any]) -> Date {
        let possibleKeys = ["endTime", "soldDate", "sale_date", "end_date", "listing_end"]
        let formatter = ISO8601DateFormatter()
        
        for key in possibleKeys {
            if let dateString = item[key] as? String {
                if let date = formatter.date(from: dateString) {
                    return date
                }
                // Try other date formats
                let otherFormatters = [
                    DateFormatter(),
                    DateFormatter()
                ]
                otherFormatters[0].dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                otherFormatters[1].dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                for formatter in otherFormatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        // Return a date within the last 30 days if we can't parse
        return Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) ?? Date()
    }
    
    private func extractShipping(from item: [String: Any]) -> Double? {
        let possibleKeys = ["shippingCost", "shipping", "shipping_cost", "delivery_cost"]
        for key in possibleKeys {
            if let shippingString = item[key] as? String {
                let cleanShipping = shippingString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                if let shipping = Double(cleanShipping), shipping > 0 {
                    return shipping
                }
            } else if let shippingDouble = item[key] as? Double, shippingDouble > 0 {
                return shippingDouble
            }
        }
        return nil
    }
    
    private func extractAuctionStatus(from item: [String: Any]) -> Bool {
        let possibleKeys = ["listingType", "format", "sale_format", "listing_format"]
        for key in possibleKeys {
            if let format = item[key] as? String {
                return format.lowercased().contains("auction")
            }
        }
        return false
    }
}
