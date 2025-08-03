//
//  AIService.swift
//  ResellAI
//
//  Complete AI Analysis Service
//

import Foundation
import SwiftUI

class AIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = 0.0
    @Published var currentStep = ""
    @Published var analysisResult: AnalysisResult?
    @Published var error: String?
    
    private let steps = [
        "Analyzing product images...",
        "Identifying brand and model...",
        "Researching eBay sold listings...",
        "Calculating market price...",
        "Generating listing suggestions..."
    ]
    
    // MARK: - Main Analysis Function
    func analyzeItem(images: [UIImage]) async {
        await MainActor.run {
            isAnalyzing = true
            analysisProgress = 0.0
            error = nil
            analysisResult = nil
        }
        
        do {
            // Step 1: Image Analysis
            await updateProgress(step: 0)
            let imageAnalysis = await analyzeImages(images)
            
            // Step 2: Product Identification
            await updateProgress(step: 1)
            let productInfo = await identifyProduct(from: imageAnalysis, images: images)
            
            // Step 3: Market Research
            await updateProgress(step: 2)
            let marketData = await researchMarket(for: productInfo)
            
            // Step 4: Price Calculation
            await updateProgress(step: 3)
            let pricing = calculatePricing(marketData: marketData, condition: productInfo.condition)
            
            // Step 5: Generate Listing
            await updateProgress(step: 4)
            let listing = generateListing(productInfo: productInfo, marketData: marketData, pricing: pricing)
            
            // Complete analysis
            let result = AnalysisResult(
                productName: productInfo.name,
                category: productInfo.category,
                brand: productInfo.brand,
                condition: productInfo.condition,
                estimatedValue: pricing.suggestedPrice,
                confidence: productInfo.confidence,
                description: listing.description,
                suggestedTitle: listing.title,
                suggestedKeywords: listing.keywords,
                marketData: marketData,
                competitionLevel: pricing.competitionLevel,
                pricingStrategy: pricing.strategy,
                listingTips: listing.tips
            )
            
            await MainActor.run {
                self.analysisResult = result
                self.analysisProgress = 1.0
                self.isAnalyzing = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isAnalyzing = false
            }
        }
    }
    
    // MARK: - Image Analysis
    private func analyzeImages(_ images: [UIImage]) async -> ImageAnalysisResult {
        guard !images.isEmpty else {
            return ImageAnalysisResult(description: "No images provided", confidence: 0.0)
        }
        
        // Convert first image to base64
        guard let imageData = images.first?.jpegData(compressionQuality: 0.8) else {
            return ImageAnalysisResult(description: "Could not process image", confidence: 0.0)
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": """
                You are an expert reseller who can identify products from photos. Analyze this image and provide:
                1. Product name and exact model if identifiable
                2. Brand name
                3. Category (clothing, shoes, electronics, etc.)
                4. Condition assessment (New with tags, Like New, Excellent, Very Good, Good, Acceptable, For parts)
                5. Notable features, size, color, style details
                6. Authentication details if applicable
                7. Estimated resale potential (1-10 scale)
                
                Be specific and detailed. Focus on details that matter for resale value.
                """
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Analyze this item for resale. What exactly is this product?"
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 1000,
            "temperature": 0.1
        ]
        
        do {
            let response = try await makeOpenAIRequest(body: requestBody)
            let choices = response["choices"] as? [[String: Any]] ?? []
            let firstChoice = choices.first
            let message = firstChoice?["message"] as? [String: Any]
            let description = message?["content"] as? String ?? "Could not analyze image"
            
            return ImageAnalysisResult(description: description, confidence: 0.85)
        } catch {
            print("Image analysis error: \(error)")
            return ImageAnalysisResult(description: "Analysis failed", confidence: 0.0)
        }
    }
    
    // MARK: - Product Identification
    private func identifyProduct(from analysis: ImageAnalysisResult, images: [UIImage]) async -> ProductInfo {
        let prompt = """
        Based on this product analysis: \(analysis.description)
        
        Extract and format the following information as JSON:
        {
            "name": "Exact product name",
            "brand": "Brand name",
            "category": "Primary category",
            "condition": "Condition assessment",
            "model": "Specific model/style",
            "size": "Size if applicable",
            "color": "Primary color",
            "year": "Release year if known",
            "confidence": 0.85
        }
        
        Use these exact condition options: "New with tags", "New without tags", "New other", "Like New", "Excellent", "Very Good", "Good", "Acceptable", "For parts or not working"
        
        Categories should be: "Clothing", "Shoes", "Electronics", "Accessories", "Home", "Collectibles", "Books", "Toys", "Sports", "Other"
        """
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a product identification expert. Always respond with valid JSON only."],
            ["role": "user", "content": prompt]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.1
        ]
        
        do {
            let response = try await makeOpenAIRequest(body: requestBody)
            let choices = response["choices"] as? [[String: Any]] ?? []
            let firstChoice = choices.first
            let message = firstChoice?["message"] as? [String: Any]
            let content = message?["content"] as? String ?? "{}"
            
            if let data = content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let conditionString = json["condition"] as? String ?? "Good"
                let condition = EbayCondition.allCases.first { $0.rawValue == conditionString } ?? .good
                
                return ProductInfo(
                    name: json["name"] as? String ?? "Unknown Item",
                    brand: json["brand"] as? String ?? "",
                    category: json["category"] as? String ?? "Other",
                    condition: condition,
                    model: json["model"] as? String ?? "",
                    size: json["size"] as? String ?? "",
                    color: json["color"] as? String ?? "",
                    year: json["year"] as? String ?? "",
                    confidence: json["confidence"] as? Double ?? 0.5
                )
            }
        } catch {
            print("Product identification error: \(error)")
        }
        
        // Fallback
        return ProductInfo(
            name: "Unknown Item",
            brand: "",
            category: "Other",
            condition: .good,
            model: "",
            size: "",
            color: "",
            year: "",
            confidence: 0.3
        )
    }
    
    // MARK: - Market Research
    private func researchMarket(for product: ProductInfo) async -> MarketData? {
        // Build search query
        let searchTerms = [product.name, product.brand, product.model]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        guard !searchTerms.isEmpty else { return nil }
        
        // Search eBay sold listings
        let soldListings = await searchEbaySoldListings(query: searchTerms, condition: product.condition)
        
        guard !soldListings.isEmpty else { return nil }
        
        // Calculate price statistics
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
        
        return MarketData(
            averagePrice: averagePrice,
            priceRange: priceRange,
            soldListings: soldListings,
            totalSold: soldListings.count,
            averageDaysToSell: nil,
            seasonalTrends: nil,
            competitorAnalysis: nil,
            demandIndicators: generateDemandIndicators(from: soldListings),
            lastUpdated: Date()
        )
    }
    
    // MARK: - eBay Sold Listings Search
    private func searchEbaySoldListings(query: String, condition: EbayCondition) async -> [EbaySoldListing] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = """
        \(Configuration.ebayFindingAPIBase)?OPERATION-NAME=findCompletedItems&SERVICE-VERSION=1.0.0&SECURITY-APPNAME=\(Configuration.ebayAPIKey)&RESPONSE-DATA-FORMAT=JSON&REST-PAYLOAD&keywords=\(encodedQuery)&itemFilter(0).name=SoldItemsOnly&itemFilter(0).value=true&itemFilter(1).name=ListingType&itemFilter(1).value(0)=FixedPrice&itemFilter(1).value(1)=Auction&sortOrder=EndTimeSoonest&paginationInput.entriesPerPage=25
        """
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let response = json["findCompletedItemsResponse"] as? [[String: Any]],
               let firstResponse = response.first,
               let searchResult = firstResponse["searchResult"] as? [[String: Any]],
               let firstResult = searchResult.first,
               let items = firstResult["item"] as? [[String: Any]] {
                
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
                        let endTime = (listingInfo?["endTime"] as? [String])?.first ?? ""
                        
                        let formatter = ISO8601DateFormatter()
                        let soldDate = formatter.date(from: endTime) ?? Date()
                        
                        let soldListing = EbaySoldListing(
                            title: title,
                            price: price,
                            condition: conditionName,
                            soldDate: soldDate,
                            shippingCost: shippingCost,
                            bestOffer: false,
                            auction: false,
                            watchers: nil
                        )
                        
                        soldListings.append(soldListing)
                    }
                }
                
                return soldListings
            }
        } catch {
            print("eBay search error: \(error)")
        }
        
        return []
    }
    
    // MARK: - Pricing Calculation
    private func calculatePricing(marketData: MarketData?, condition: EbayCondition) -> PricingInfo {
        guard let marketData = marketData else {
            return PricingInfo(
                suggestedPrice: 10.0,
                competitionLevel: .low,
                strategy: .market
            )
        }
        
        let basePrice = marketData.averagePrice
        let conditionMultiplier = condition.priceMultiplier
        let adjustedPrice = basePrice * conditionMultiplier
        
        // Determine competition level based on number of sold listings
        let competitionLevel: CompetitionLevel
        switch marketData.totalSold {
        case 0...5: competitionLevel = .low
        case 6...15: competitionLevel = .moderate
        case 16...30: competitionLevel = .high
        default: competitionLevel = .veryHigh
        }
        
        // Determine pricing strategy
        let strategy: PricingStrategy = competitionLevel == .low ? .premium : .market
        
        return PricingInfo(
            suggestedPrice: adjustedPrice * strategy.priceMultiplier,
            competitionLevel: competitionLevel,
            strategy: strategy
        )
    }
    
    // MARK: - Listing Generation
    private func generateListing(productInfo: ProductInfo, marketData: MarketData?, pricing: PricingInfo) -> ListingInfo {
        let title = generateTitle(product: productInfo)
        let description = generateDescription(product: productInfo, marketData: marketData)
        let keywords = generateKeywords(product: productInfo)
        let tips = generateListingTips(product: productInfo, pricing: pricing)
        
        return ListingInfo(
            title: title,
            description: description,
            keywords: keywords,
            tips: tips
        )
    }
    
    // MARK: - Helper Functions
    private func updateProgress(step: Int) async {
        await MainActor.run {
            self.analysisProgress = Double(step) / Double(self.steps.count - 1)
            self.currentStep = step < self.steps.count ? self.steps[step] : "Completing analysis..."
        }
        
        // Add small delay for UI feedback
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    private func makeOpenAIRequest(body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: Configuration.openAIEndpoint) else {
            throw NSError(domain: "Invalid URL", code: 0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Configuration.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "API Error", code: 0)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Invalid JSON", code: 0)
        }
        
        return json
    }
    
    private func generateDemandIndicators(from listings: [EbaySoldListing]) -> [String] {
        var indicators: [String] = []
        
        if listings.count > 10 {
            indicators.append("High sales volume")
        }
        
        let recentSales = listings.filter {
            Calendar.current.dateInterval(of: .weekOfYear, for: $0.soldDate)?.contains(Date()) ?? false
        }
        
        if recentSales.count > 3 {
            indicators.append("Active current demand")
        }
        
        return indicators
    }
    
    private func generateTitle(product: ProductInfo) -> String {
        var components: [String] = []
        
        if !product.brand.isEmpty {
            components.append(product.brand)
        }
        
        components.append(product.name)
        
        if !product.size.isEmpty {
            components.append("Size \(product.size)")
        }
        
        if !product.color.isEmpty {
            components.append(product.color)
        }
        
        components.append(product.condition.rawValue)
        
        return components.joined(separator: " ")
    }
    
    private func generateDescription(product: ProductInfo, marketData: MarketData?) -> String {
        var description = "Excellent \(product.name)"
        
        if !product.brand.isEmpty {
            description += " by \(product.brand)"
        }
        
        description += " in \(product.condition.rawValue) condition."
        
        if !product.model.isEmpty {
            description += " Model: \(product.model)."
        }
        
        if !product.size.isEmpty {
            description += " Size: \(product.size)."
        }
        
        description += "\n\nFast shipping with tracking. Returns accepted."
        
        return description
    }
    
    private func generateKeywords(product: ProductInfo) -> [String] {
        var keywords: [String] = []
        
        if !product.brand.isEmpty {
            keywords.append(product.brand.lowercased())
        }
        
        keywords.append(contentsOf: product.name.lowercased().components(separatedBy: " "))
        
        if !product.model.isEmpty {
            keywords.append(product.model.lowercased())
        }
        
        keywords.append(product.category.lowercased())
        keywords.append(product.condition.rawValue.lowercased())
        
        return Array(Set(keywords)).filter { $0.count > 2 }
    }
    
    private func generateListingTips(product: ProductInfo, pricing: PricingInfo) -> [String] {
        var tips: [String] = []
        
        switch pricing.competitionLevel {
        case .low:
            tips.append("Low competition - you can price at premium")
        case .moderate:
            tips.append("Moderate competition - price competitively")
        case .high:
            tips.append("High competition - consider quick sale pricing")
        case .veryHigh:
            tips.append("Very high competition - focus on great photos and description")
        }
        
        if product.confidence < 0.7 {
            tips.append("Consider getting more product details for better listing")
        }
        
        tips.append("Use all available photo slots")
        tips.append("Research similar sold listings regularly")
        
        return tips
    }
}

// MARK: - Supporting Structures
struct ImageAnalysisResult {
    let description: String
    let confidence: Double
}

struct ProductInfo {
    let name: String
    let brand: String
    let category: String
    let condition: EbayCondition
    let model: String
    let size: String
    let color: String
    let year: String
    let confidence: Double
}

struct PricingInfo {
    let suggestedPrice: Double
    let competitionLevel: CompetitionLevel
    let strategy: PricingStrategy
}

struct ListingInfo {
    let title: String
    let description: String
    let keywords: [String]
    let tips: [String]
}
