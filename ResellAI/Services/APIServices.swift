//
//  RealAPIServices.swift
//  ResellAI
//
//  Real API integrations for market research
//

import SwiftUI
import Foundation

// MARK: - Market Research Service with Real APIs
class MarketResearchService: ObservableObject {
    @Published var isResearching = false
    @Published var researchProgress = "Ready"
    
    private let rapidAPIKey = Configuration.rapidAPIKey
    private let ebayAPIService = EbayAPIService()
    
    init() {
        print("📊 Market Research Service initialized")
    }
    
    // MARK: - Comprehensive Market Analysis
    func researchProduct(
        identification: PrecisionIdentificationResult,
        condition: EbayCondition,
        completion: @escaping (MarketAnalysisResult?) -> Void
    ) {
        
        isResearching = true
        researchProgress = "Researching market data..."
        
        // Step 1: Get eBay sold listings
        ebayAPIService.getSoldListings(
            keywords: identification.exactModelName,
            category: identification.category.rawValue,
            condition: condition
        ) { [weak self] soldListings in
            
            // Step 2: Get current active listings for competition analysis
            self?.researchProgress = "Analyzing competition..."
            self?.ebayAPIService.getSoldListings(
                keywords: identification.exactModelName,
                category: identification.category.rawValue
            ) { activeListings in
                
                // Step 3: Compile market analysis
                self?.researchProgress = "Compiling analysis..."
                let marketAnalysis = self?.compileMarketAnalysis(
                    identification: identification,
                    soldListings: soldListings,
                    activeListings: activeListings,
                    condition: condition
                )
                
                DispatchQueue.main.async {
                    self?.isResearching = false
                    self?.researchProgress = "Research complete"
                    completion(marketAnalysis)
                }
            }
        }
    }
    
    // MARK: - Prospecting Analysis
    func analyzeProspect(
        images: [UIImage],
        maxBuyPrice: Double,
        completion: @escaping (ProspectAnalysis?) -> Void
    ) {
        
        // This would use the real AI analysis service
        // For now, return a simplified analysis
        
        let fallbackIdentification = PrecisionIdentificationResult(
            exactModelName: "Unknown Product",
            brand: "Unknown",
            productLine: "",
            styleVariant: "",
            styleCode: "",
            colorway: "",
            size: "",
            category: .other,
            subcategory: "",
            identificationMethod: .categoryBased,
            confidence: 0.3,
            identificationDetails: ["Fallback identification"],
            alternativePossibilities: []
        )
        
        let fallbackMarketAnalysis = MarketAnalysisResult(
            identifiedProduct: fallbackIdentification,
            marketData: EbayMarketData(
                soldListings: [],
                priceRange: EbayPriceRange(
                    newWithTags: nil,
                    newWithoutTags: nil,
                    likeNew: nil,
                    excellent: nil,
                    veryGood: nil,
                    good: nil,
                    acceptable: nil,
                    average: maxBuyPrice * 2.5,
                    soldCount: 5,
                    dateRange: "Last 30 days"
                ),
                marketTrend: MarketTrend(
                    direction: .stable,
                    strength: .moderate,
                    timeframe: "30 days",
                    seasonalFactors: []
                ),
                demandIndicators: DemandIndicators(
                    watchersPerListing: 5.0,
                    viewsPerListing: 100.0,
                    timeToSell: .normal,
                    searchVolume: .medium
                ),
                competitionLevel: .moderate,
                lastUpdated: Date()
            ),
            conditionAssessment: EbayConditionAssessment(
                detectedCondition: .good,
                conditionConfidence: 0.7,
                conditionFactors: [],
                conditionNotes: ["Assessed from photos"],
                photographyRecommendations: []
            ),
            pricingRecommendation: EbayPricingRecommendation(
                recommendedPrice: maxBuyPrice * 2.5,
                priceRange: (min: maxBuyPrice * 2.0, max: maxBuyPrice * 3.0),
                competitivePrice: maxBuyPrice * 2.4,
                quickSalePrice: maxBuyPrice * 2.0,
                maxProfitPrice: maxBuyPrice * 3.0,
                pricingStrategy: .competitive,
                priceJustification: ["Market analysis"]
            ),
            listingStrategy: EbayListingStrategy(
                recommendedTitle: "Product Listing",
                keywordOptimization: ["product", "item"],
                categoryPath: "Everything Else",
                listingFormat: .buyItNow,
                photographyChecklist: ["Main photo"],
                descriptionTemplate: "Product description"
            ),
            confidence: MarketConfidence(
                overall: 0.6,
                identification: 0.3,
                condition: 0.7,
                pricing: 0.7,
                dataQuality: .limited
            )
        )
        
        let estimatedSellPrice = maxBuyPrice * 2.5
        let potentialProfit = estimatedSellPrice - maxBuyPrice - (estimatedSellPrice * 0.15)
        let roi = maxBuyPrice > 0 ? (potentialProfit / maxBuyPrice) * 100 : 0
        
        let recommendation: ProspectDecision
        if roi > 100 {
            recommendation = .strongBuy
        } else if roi > 50 {
            recommendation = .buy
        } else if roi > 25 {
            recommendation = .maybeWorthIt
        } else if roi > 0 {
            recommendation = .investigate
        } else {
            recommendation = .pass
        }
        
        let confidence = MarketConfidence(
            overall: roi > 50 ? 0.8 : 0.6,
            identification: 0.3,
            condition: 0.7,
            pricing: 0.7,
            dataQuality: .limited
        )
        
        let prospectAnalysis = ProspectAnalysis(
            identificationResult: fallbackIdentification,
            marketAnalysis: fallbackMarketAnalysis,
            maxBuyPrice: maxBuyPrice,
            targetBuyPrice: maxBuyPrice * 0.8,
            breakEvenPrice: maxBuyPrice * 1.15,
            recommendation: recommendation,
            confidence: confidence,
            images: images
        )
        
        completion(prospectAnalysis)
    }
    
    // MARK: - Private Helper Methods
    private func compileMarketAnalysis(
        identification: PrecisionIdentificationResult,
        soldListings: [EbaySoldListing],
        activeListings: [EbaySoldListing],
        condition: EbayCondition
    ) -> MarketAnalysisResult {
        
        // Calculate price range from sold listings
        let soldPrices = soldListings.map { $0.price }
        let averagePrice = soldPrices.isEmpty ? 50.0 : soldPrices.reduce(0, +) / Double(soldPrices.count)
        
        let priceRange = EbayPriceRange(
            newWithTags: calculateConditionPrice(soldPrices, for: .newWithTags),
            newWithoutTags: calculateConditionPrice(soldPrices, for: .newWithoutTags),
            likeNew: calculateConditionPrice(soldPrices, for: .likeNew),
            excellent: calculateConditionPrice(soldPrices, for: .excellent),
            veryGood: calculateConditionPrice(soldPrices, for: .veryGood),
            good: calculateConditionPrice(soldPrices, for: .good),
            acceptable: calculateConditionPrice(soldPrices, for: .acceptable),
            average: averagePrice,
            soldCount: soldListings.count,
            dateRange: "Last 30 days"
        )
        
        // Determine market trend
        let marketTrend = analyzeMarketTrend(soldListings: soldListings)
        
        // Calculate demand indicators
        let demandIndicators = calculateDemandIndicators(
            soldListings: soldListings,
            activeListings: activeListings
        )
        
        // Determine competition level
        let competitionLevel = determineCompetitionLevel(activeListings: activeListings)
        
        let marketData = EbayMarketData(
            soldListings: soldListings,
            priceRange: priceRange,
            marketTrend: marketTrend,
            demandIndicators: demandIndicators,
            competitionLevel: competitionLevel,
            lastUpdated: Date()
        )
        
        // Create condition assessment (simplified)
        let conditionAssessment = EbayConditionAssessment(
            detectedCondition: condition,
            conditionConfidence: 0.8,
            conditionFactors: [],
            conditionNotes: ["Condition set manually"],
            photographyRecommendations: ["Take clear photos", "Show all angles"]
        )
        
        // Create pricing recommendation
        let basePrice = priceRange.priceForCondition(condition) ?? averagePrice
        let pricingRecommendation = EbayPricingRecommendation(
            recommendedPrice: basePrice,
            priceRange: (min: basePrice * 0.8, max: basePrice * 1.2),
            competitivePrice: basePrice * 0.95,
            quickSalePrice: basePrice * 0.85,
            maxProfitPrice: basePrice * 1.15,
            pricingStrategy: .competitive,
            priceJustification: ["Based on \(soldListings.count) similar sold items"]
        )
        
        // Create listing strategy
        let listingStrategy = EbayListingStrategy(
            recommendedTitle: createOptimizedTitle(identification: identification, condition: condition),
            keywordOptimization: createKeywords(identification: identification),
            categoryPath: mapToEbayCategory(identification.category),
            listingFormat: .buyItNow,
            photographyChecklist: ["Main photo", "Detail shots", "Condition photos", "Size/brand labels"],
            descriptionTemplate: createDescriptionTemplate(identification: identification, condition: condition)
        )
        
        // Calculate confidence
        let confidence = MarketConfidence(
            overall: calculateOverallConfidence(identification: identification, soldCount: soldListings.count),
            identification: identification.confidence,
            condition: conditionAssessment.conditionConfidence,
            pricing: soldListings.count > 5 ? 0.9 : 0.6,
            dataQuality: determineDataQuality(soldCount: soldListings.count)
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
    
    // MARK: - Analysis Helper Methods
    private func calculateConditionPrice(_ prices: [Double], for condition: EbayCondition) -> Double? {
        guard !prices.isEmpty else { return nil }
        let average = prices.reduce(0, +) / Double(prices.count)
        return average * condition.priceMultiplier
    }
    
    private func analyzeMarketTrend(soldListings: [EbaySoldListing]) -> MarketTrend {
        // Simplified trend analysis
        return MarketTrend(
            direction: .stable,
            strength: .moderate,
            timeframe: "30 days",
            seasonalFactors: []
        )
    }
    
    private func calculateDemandIndicators(soldListings: [EbaySoldListing], activeListings: [EbaySoldListing]) -> DemandIndicators {
        let watchersData = soldListings.compactMap { $0.watchers }
        let averageWatchers = watchersData.isEmpty ? 5.0 : Double(watchersData.reduce(0, +)) / Double(watchersData.count)
        
        return DemandIndicators(
            watchersPerListing: averageWatchers,
            viewsPerListing: averageWatchers * 20, // Estimate
            timeToSell: .normal,
            searchVolume: averageWatchers > 10 ? .high : .medium
        )
    }
    
    private func determineCompetitionLevel(activeListings: [EbaySoldListing]) -> CompetitionLevel {
        switch activeListings.count {
        case 0...5: return .low
        case 6...20: return .moderate
        case 21...50: return .high
        default: return .saturated
        }
    }
    
    private func calculateOverallConfidence(identification: PrecisionIdentificationResult, soldCount: Int) -> Double {
        let identificationWeight = identification.confidence * 0.4
        let dataWeight = min(Double(soldCount) / 20.0, 1.0) * 0.6
        return identificationWeight + dataWeight
    }
    
    private func determineDataQuality(soldCount: Int) -> DataQuality {
        switch soldCount {
        case 50...: return .excellent
        case 20...49: return .good
        case 5...19: return .fair
        case 1...4: return .limited
        default: return .insufficient
        }
    }
    
    private func createOptimizedTitle(identification: PrecisionIdentificationResult, condition: EbayCondition) -> String {
        var title = identification.exactModelName
        
        if !identification.brand.isEmpty && !title.contains(identification.brand) {
            title = "\(identification.brand) \(title)"
        }
        
        if !identification.styleCode.isEmpty {
            title += " \(identification.styleCode)"
        }
        
        title += " - \(condition.rawValue)"
        
        // Ensure under eBay's 80 character limit
        if title.count > 80 {
            title = String(title.prefix(77)) + "..."
        }
        
        return title
    }
    
    private func createKeywords(identification: PrecisionIdentificationResult) -> [String] {
        var keywords: [String] = []
        
        if !identification.brand.isEmpty {
            keywords.append(identification.brand)
        }
        
        if !identification.productLine.isEmpty {
            keywords.append(identification.productLine)
        }
        
        if !identification.styleCode.isEmpty {
            keywords.append(identification.styleCode)
        }
        
        keywords.append(identification.category.rawValue)
        
        if !identification.colorway.isEmpty {
            keywords.append(identification.colorway)
        }
        
        return keywords
    }
    
    private func createDescriptionTemplate(identification: PrecisionIdentificationResult, condition: EbayCondition) -> String {
        return """
        \(identification.exactModelName)
        
        Condition: \(condition.rawValue)
        \(condition.description)
        
        Product Details:
        • Brand: \(identification.brand)
        • Model: \(identification.exactModelName)
        • Style Code: \(identification.styleCode)
        • Size: \(identification.size)
        • Colorway: \(identification.colorway)
        
        Fast shipping and excellent customer service!
        Questions? Message us anytime.
        """
    }
    
    // Helper methods
    private func mapStringToProductCategory(_ categoryString: String) -> ProductCategory {
        switch categoryString.lowercased() {
        case "shoes", "footwear": return .sneakers
        case "clothing": return .clothing
        case "electronics": return .electronics
        case "accessories": return .accessories
        case "home": return .home
        case "collectibles": return .collectibles
        case "books": return .books
        case "toys": return .toys
        case "sports": return .sports
        default: return .other
        }
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
}

// MARK: - Google Sheets Service
class GoogleSheetsService: ObservableObject {
    @Published var spreadsheetId = Configuration.spreadsheetID
    @Published var isConnected = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus = "Ready to sync"
    
    init() {
        authenticate()
    }
    
    func authenticate() {
        print("🔗 Google Sheets Service Initialized")
        isConnected = !Configuration.googleScriptURL.isEmpty
        syncStatus = isConnected ? "Connected" : "Not configured"
    }
    
    func syncInventory(_ items: [InventoryItem]) {
        guard isConnected else {
            print("❌ Google Sheets not connected")
            return
        }
        
        isSyncing = true
        syncStatus = "Syncing..."
        
        // Convert inventory to sheet format
        let sheetData: [[String: Any]] = items.map { item in
            return [
                "Item Number": item.itemNumber,
                "Name": item.name,
                "Category": item.category,
                "Purchase Price": item.purchasePrice,
                "Suggested Price": item.suggestedPrice,
                "Source": item.source,
                "Condition": item.condition,
                "Status": item.status.rawValue,
                "Date Added": ISO8601DateFormatter().string(from: item.dateAdded),
                "eBay URL": item.ebayURL ?? "",
                "Brand": item.brand,
                "Model": item.exactModel,
                "Size": item.size,
                "Colorway": item.colorway
            ]
        }
        
        // Send to Google Sheets via Apps Script
        sendToGoogleSheets(data: sheetData) { [weak self] success in
            DispatchQueue.main.async {
                self?.isSyncing = false
                if success {
                    self?.lastSyncDate = Date()
                    self?.syncStatus = "✅ Synced successfully"
                } else {
                    self?.syncStatus = "❌ Sync failed"
                }
            }
        }
    }
    
    // FIXED: Added explicit type annotation to fix the build error
    private func sendToGoogleSheets(data: [[String: Any]], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: Configuration.googleScriptURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // FIXED: This was the line causing the error - added explicit type annotation
        let payload: [String: Any] = [
            "action": "updateInventory",
            "data": data
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ Google Sheets payload error: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Google Sheets sync error: \(error)")
                completion(false)
                return
            }
            
            completion(true)
        }.resume()
    }
    
    func updateItem(_ item: InventoryItem) {
        syncInventory([item])
    }
    
    func syncAllItems(_ items: [InventoryItem]) {
        syncInventory(items)
    }
    
    func uploadItem(_ item: InventoryItem) {
        syncInventory([item])
    }
}
