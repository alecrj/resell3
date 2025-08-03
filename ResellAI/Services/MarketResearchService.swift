//
//  MarketResearchService.swift
//  ResellAI
//
//  Real Market Research with eBay Sold Comp Integration - Fixed
//

import SwiftUI
import Foundation

// MARK: - Real Market Research Service Using eBay Sold Comps
class MarketResearchService: ObservableObject {
    @Published var isResearching = false
    @Published var researchProgress = "Ready"
    
    private let ebayAPIService = EbayAPIService()
    
    init() {
        print("📊 Market Research Service initialized with real eBay integration")
    }
    
    // MARK: - Main Product Research with Real eBay Data
    func researchProduct(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        completion: @escaping (MarketAnalysisResult?) -> Void
    ) {
        
        isResearching = true
        researchProgress = "Researching market data..."
        
        print("🔍 Starting market research for: \(identification.exactModelName)")
        
        // Create comprehensive search queries from AI identification
        let searchQueries = createSearchQueries(from: identification)
        
        // Search eBay for real sold comps using multiple queries
        ebayAPIService.searchWithMultipleQueries(keywordSets: searchQueries) { [weak self] soldListings in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isResearching = false
                self.researchProgress = "Research complete"
                
                if soldListings.isEmpty {
                    print("⚠️ No sold comps found - creating fallback analysis")
                    let fallbackAnalysis = self.createFallbackAnalysis(identification: identification, condition: condition)
                    completion(fallbackAnalysis)
                } else {
                    print("✅ Found \(soldListings.count) real sold comps")
                    let marketAnalysis = self.createMarketAnalysisFromComps(
                        identification: identification,
                        soldListings: soldListings,
                        condition: condition
                    )
                    completion(marketAnalysis)
                }
            }
        }
    }
    
    // MARK: - Create Search Queries from AI Identification
    private func createSearchQueries(from identification: PrecisionIdentificationResult) -> [[String]] {
        var queries: [[String]] = []
        
        // Query 1: Most specific - Style code if available
        if !identification.styleCode.isEmpty {
            var query1 = [identification.styleCode]
            if !identification.brand.isEmpty {
                query1.insert(identification.brand, at: 0)
            }
            queries.append(query1)
        }
        
        // Query 2: Brand + exact model name
        if !identification.brand.isEmpty && !identification.exactModelName.isEmpty {
            let query2 = [identification.brand, identification.exactModelName]
            queries.append(query2)
        }
        
        // Query 3: Brand + product line + key details
        if !identification.brand.isEmpty && !identification.productLine.isEmpty {
            var query3 = [identification.brand, identification.productLine]
            
            // Add size if available and relevant (mainly for shoes/clothing)
            if !identification.size.isEmpty &&
               (identification.category == .sneakers || identification.category == .clothing) {
                query3.append("size")
                query3.append(identification.size)
            }
            
            // Add colorway if specific
            if !identification.colorway.isEmpty && identification.colorway.count > 3 {
                query3.append(identification.colorway)
            }
            
            queries.append(query3)
        }
        
        // Query 4: Fallback - just the exact model name
        if !identification.exactModelName.isEmpty {
            queries.append([identification.exactModelName])
        }
        
        // Query 5: Brand only if no other queries worked
        if queries.isEmpty && !identification.brand.isEmpty {
            queries.append([identification.brand])
        }
        
        print("🔍 Generated \(queries.count) search queries for eBay:")
        for (index, query) in queries.enumerated() {
            print("  Query \(index + 1): \(query.joined(separator: " "))")
        }
        
        return queries
    }
    
    // MARK: - Create Market Analysis from Real eBay Comps
    private func createMarketAnalysisFromComps(
        identification: PrecisionIdentificationResult,
        soldListings: [EbaySoldListing],
        condition: EbayCondition
    ) -> MarketAnalysisResult {
        
        // Analyze the comps data
        let compAnalysis = ebayAPIService.analyzeComps(soldListings)
        
        // Create eBay price range from real data
        let priceRange = createPriceRangeFromComps(soldListings: soldListings)
        
        // Market trend analysis
        let marketTrend = analyzeMarketTrend(soldListings: soldListings)
        
        // Demand indicators from real data
        let demandIndicators = calculateDemandFromComps(compAnalysis: compAnalysis)
        
        // Competition level
        let competitionLevel = determineCompetitionLevel(soldCount: soldListings.count)
        
        // Create market data with real eBay information
        let marketData = EbayMarketData(
            soldListings: soldListings,
            priceRange: priceRange,
            marketTrend: marketTrend,
            demandIndicators: demandIndicators,
            competitionLevel: competitionLevel,
            lastUpdated: Date()
        )
        
        // Condition assessment
        let conditionAssessment = EbayConditionAssessment(
            detectedCondition: condition,
            conditionConfidence: 0.85,
            conditionFactors: [],
            conditionNotes: createConditionNotes(for: condition, comps: compAnalysis),
            photographyRecommendations: [
                "Clear photos of all angles",
                "Close-ups of any wear or flaws",
                "Brand and size tags visible",
                "Good lighting to show true condition"
            ]
        )
        
        // Real pricing recommendation from eBay comps
        let pricingRecommendation = ebayAPIService.getPricingFromComps(soldListings, condition: condition)
        
        // Listing strategy
        let listingStrategy = createListingStrategy(
            identification: identification,
            condition: condition,
            marketData: marketData
        )
        
        // Market confidence based on real data
        let confidence = calculateMarketConfidence(
            identification: identification,
            compAnalysis: compAnalysis
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
    
    // MARK: - Create Price Range from Real Comps - FIXED
    private func createPriceRangeFromComps(soldListings: [EbaySoldListing]) -> EbayPriceRange {
        let prices = soldListings.map { $0.price }
        let totalAveragePrice = prices.isEmpty ? 0 : prices.reduce(0, +) / Double(prices.count)
        
        // Group by condition and calculate average for each
        let conditionGroups = Dictionary(grouping: soldListings) { listing in
            normalizeCondition(listing.condition)
        }
        
        return EbayPriceRange(
            newWithTags: averagePrice(for: "New with tags", in: conditionGroups),
            newWithoutTags: averagePrice(for: "New without tags", in: conditionGroups),
            likeNew: averagePrice(for: "Like New", in: conditionGroups),
            excellent: averagePrice(for: "Excellent", in: conditionGroups),
            veryGood: averagePrice(for: "Very Good", in: conditionGroups),
            good: averagePrice(for: "Good", in: conditionGroups),
            acceptable: averagePrice(for: "Acceptable", in: conditionGroups),
            average: totalAveragePrice,
            soldCount: soldListings.count,
            dateRange: "Last 30 days"
        )
    }
    
    // MARK: - Normalize eBay Condition Names
    private func normalizeCondition(_ condition: String) -> String {
        let lowercased = condition.lowercased()
        
        if lowercased.contains("new") && lowercased.contains("tag") {
            return "New with tags"
        } else if lowercased.contains("new") && !lowercased.contains("tag") {
            return "New without tags"
        } else if lowercased.contains("like new") || lowercased.contains("mint") {
            return "Like New"
        } else if lowercased.contains("excellent") || lowercased.contains("exc") {
            return "Excellent"
        } else if lowercased.contains("very good") || lowercased.contains("great") {
            return "Very Good"
        } else if lowercased.contains("good") {
            return "Good"
        } else if lowercased.contains("acceptable") || lowercased.contains("fair") {
            return "Acceptable"
        } else {
            return "Good" // Default
        }
    }
    
    // MARK: - Calculate Average Price for Condition
    private func averagePrice(for condition: String, in groups: [String: [EbaySoldListing]]) -> Double? {
        guard let listings = groups[condition], !listings.isEmpty else { return nil }
        let prices = listings.map { $0.price }
        return prices.reduce(0, +) / Double(prices.count)
    }
    
    // MARK: - Analyze Market Trend from Real Data
    private func analyzeMarketTrend(soldListings: [EbaySoldListing]) -> MarketTrend {
        let sortedListings = soldListings.sorted { $0.soldDate > $1.soldDate }
        
        // Compare recent sales vs older sales
        let recentSales = sortedListings.prefix(10)
        let olderSales = sortedListings.dropFirst(10).prefix(10)
        
        if !recentSales.isEmpty && !olderSales.isEmpty {
            let recentAvg = recentSales.map { $0.price }.reduce(0, +) / Double(recentSales.count)
            let olderAvg = olderSales.map { $0.price }.reduce(0, +) / Double(olderSales.count)
            
            let priceChange = (recentAvg - olderAvg) / olderAvg
            
            let direction: TrendDirection
            let strength: TrendStrength
            
            if priceChange > 0.15 {
                direction = .increasing
                strength = .strong
            } else if priceChange > 0.05 {
                direction = .increasing
                strength = .moderate
            } else if priceChange < -0.15 {
                direction = .decreasing
                strength = .strong
            } else if priceChange < -0.05 {
                direction = .decreasing
                strength = .moderate
            } else {
                direction = .stable
                strength = .moderate
            }
            
            return MarketTrend(
                direction: direction,
                strength: strength,
                timeframe: "30 days",
                seasonalFactors: []
            )
        }
        
        return MarketTrend(
            direction: .stable,
            strength: .moderate,
            timeframe: "30 days",
            seasonalFactors: []
        )
    }
    
    // MARK: - Calculate Demand from Comp Analysis
    private func calculateDemandFromComps(compAnalysis: CompAnalysis) -> DemandIndicators {
        let timeToSell: TimeToSell
        switch compAnalysis.averageDaysToSell {
        case 0...3:
            timeToSell = .immediate
        case 4...7:
            timeToSell = .fast
        case 8...21:
            timeToSell = .normal
        case 22...60:
            timeToSell = .slow
        default:
            timeToSell = .difficult
        }
        
        let searchVolume: SearchVolume
        switch compAnalysis.totalSales {
        case 30...:
            searchVolume = .high
        case 10...29:
            searchVolume = .medium
        default:
            searchVolume = .low
        }
        
        return DemandIndicators(
            watchersPerListing: 0, // Not available from sold data
            viewsPerListing: 0,    // Not available from sold data
            timeToSell: timeToSell,
            searchVolume: searchVolume
        )
    }
    
    // MARK: - Determine Competition Level
    private func determineCompetitionLevel(soldCount: Int) -> CompetitionLevel {
        switch soldCount {
        case 0...5:
            return .low
        case 6...20:
            return .moderate
        case 21...50:
            return .high
        default:
            return .saturated
        }
    }
    
    // MARK: - Create Condition Notes
    private func createConditionNotes(for condition: EbayCondition, comps: CompAnalysis) -> [String] {
        var notes: [String] = []
        
        notes.append("Based on \(comps.totalSales) recent sales")
        
        if comps.totalSales > 20 {
            notes.append("High confidence in pricing due to good sales data")
        } else if comps.totalSales > 5 {
            notes.append("Moderate confidence in pricing")
        } else {
            notes.append("Limited sales data - price estimate based on available comps")
        }
        
        notes.append("Average time to sell: \(Int(comps.averageDaysToSell)) days")
        
        return notes
    }
    
    // MARK: - Create Listing Strategy
    private func createListingStrategy(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        marketData: EbayMarketData
    ) -> EbayListingStrategy {
        
        let title = createOptimizedTitle(identification: identification, condition: condition)
        let keywords = createOptimizedKeywords(identification: identification)
        let category = mapToEbayCategory(identification.category)
        
        return EbayListingStrategy(
            recommendedTitle: title,
            keywordOptimization: keywords,
            categoryPath: category,
            listingFormat: .buyItNow,
            photographyChecklist: [
                "Main product photo with good lighting",
                "Multiple angles (front, back, sides, top)",
                "Close-ups of brand tags and labels",
                "Size tag or measurement reference",
                "Any wear, flaws, or imperfections",
                "Style code or model number if visible",
                "Comparison with authentic reference if needed"
            ],
            descriptionTemplate: createDescriptionTemplate(identification: identification, condition: condition)
        )
    }
    
    // MARK: - Calculate Market Confidence
    private func calculateMarketConfidence(
        identification: PrecisionIdentificationResult,
        compAnalysis: CompAnalysis
    ) -> MarketConfidence {
        
        let dataQuality: DataQuality
        switch compAnalysis.totalSales {
        case 50...:
            dataQuality = .excellent
        case 20...49:
            dataQuality = .good
        case 5...19:
            dataQuality = .fair
        case 1...4:
            dataQuality = .limited
        default:
            dataQuality = .insufficient
        }
        
        let overallConfidence = (
            identification.confidence * 0.4 +
            compAnalysis.marketConfidence * 0.6
        )
        
        return MarketConfidence(
            overall: overallConfidence,
            identification: identification.confidence,
            condition: 0.85,
            pricing: compAnalysis.marketConfidence,
            dataQuality: dataQuality
        )
    }
    
    // MARK: - Helper Methods
    private func createOptimizedTitle(identification: PrecisionIdentificationResult, condition: EbayCondition) -> String {
        var components: [String] = []
        
        if !identification.brand.isEmpty {
            components.append(identification.brand)
        }
        
        if !identification.exactModelName.isEmpty {
            components.append(identification.exactModelName)
        }
        
        if !identification.styleCode.isEmpty {
            components.append(identification.styleCode)
        }
        
        if !identification.size.isEmpty &&
           (identification.category == .sneakers || identification.category == .clothing) {
            components.append("Size \(identification.size)")
        }
        
        components.append(condition.rawValue)
        
        let title = components.joined(separator: " ")
        return String(title.prefix(80)) // eBay's title limit
    }
    
    private func createOptimizedKeywords(identification: PrecisionIdentificationResult) -> [String] {
        var keywords: Set<String> = []
        
        if !identification.brand.isEmpty {
            keywords.insert(identification.brand)
        }
        
        if !identification.productLine.isEmpty {
            keywords.insert(identification.productLine)
        }
        
        if !identification.styleCode.isEmpty {
            keywords.insert(identification.styleCode)
        }
        
        if !identification.colorway.isEmpty {
            keywords.insert(identification.colorway)
        }
        
        if !identification.size.isEmpty {
            keywords.insert(identification.size)
        }
        
        keywords.insert(identification.category.rawValue)
        
        return Array(keywords)
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
    
    private func createDescriptionTemplate(identification: PrecisionIdentificationResult, condition: EbayCondition) -> String {
        return """
        \(identification.exactModelName)
        
        CONDITION: \(condition.rawValue)
        \(condition.description)
        
        PRODUCT DETAILS:
        • Brand: \(identification.brand)
        • Model: \(identification.exactModelName)
        • Style Code: \(identification.styleCode)
        • Size: \(identification.size)
        • Colorway: \(identification.colorway)
        • Category: \(identification.category.rawValue)
        
        MARKET VERIFIED:
        • Researched and priced based on recent sold comps
        • Authentic item verified through AI analysis
        • Professionally analyzed and described
        
        SHIPPING & RETURNS:
        • Fast and secure shipping
        • Carefully packaged for protection
        • 30-day return policy
        • Tracking provided
        
        Questions? Message us anytime - we respond quickly!
        """
    }
    
    // MARK: - Fallback Analysis (when no comps found)
    private func createFallbackAnalysis(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition
    ) -> MarketAnalysisResult {
        
        // Estimate price based on category and brand
        let estimatedPrice = estimatePrice(identification: identification)
        
        // Create minimal market data for fallback
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
            dateRange: "No recent sales found"
        )
        
        let marketData = EbayMarketData(
            soldListings: [],
            priceRange: priceRange,
            marketTrend: MarketTrend(direction: .stable, strength: .weak, timeframe: "Unknown", seasonalFactors: []),
            demandIndicators: DemandIndicators(watchersPerListing: 0, viewsPerListing: 0, timeToSell: .normal, searchVolume: .low),
            competitionLevel: .low,
            lastUpdated: Date()
        )
        
        let conditionAssessment = EbayConditionAssessment(
            detectedCondition: condition,
            conditionConfidence: 0.7,
            conditionFactors: [],
            conditionNotes: ["No recent sales found for exact match", "Price estimate based on similar items"],
            photographyRecommendations: ["Take detailed photos to help with accurate pricing"]
        )
        
        let pricingRecommendation = EbayPricingRecommendation(
            recommendedPrice: estimatedPrice * condition.priceMultiplier,
            priceRange: (min: estimatedPrice * 0.7, max: estimatedPrice * 1.2),
            competitivePrice: estimatedPrice * 0.9,
            quickSalePrice: estimatedPrice * 0.8,
            maxProfitPrice: estimatedPrice * 1.1,
            pricingStrategy: .discount,
            priceJustification: ["Estimated price - no recent sales found", "Consider researching similar items"]
        )
        
        let listingStrategy = createListingStrategy(identification: identification, condition: condition, marketData: marketData)
        
        let confidence = MarketConfidence(
            overall: 0.4,
            identification: identification.confidence,
            condition: 0.7,
            pricing: 0.3,
            dataQuality: .insufficient
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
    
    // MARK: - Price Estimation for Fallback
    private func estimatePrice(identification: PrecisionIdentificationResult) -> Double {
        let brand = identification.brand.lowercased()
        let category = identification.category
        
        // Brand-based pricing
        if brand.contains("nike") || brand.contains("jordan") {
            return category == .sneakers ? 120.0 : 45.0
        } else if brand.contains("adidas") || brand.contains("yeezy") {
            return category == .sneakers ? 100.0 : 40.0
        } else if brand.contains("apple") {
            return 350.0
        } else if brand.contains("supreme") || brand.contains("off-white") {
            return 200.0
        }
        
        // Category-based pricing
        switch category {
        case .sneakers: return 60.0
        case .electronics: return 150.0
        case .clothing: return 25.0
        case .accessories: return 30.0
        case .collectibles: return 75.0
        default: return 35.0
        }
    }
}
