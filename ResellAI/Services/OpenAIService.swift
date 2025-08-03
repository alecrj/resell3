//
//  OpenAIService.swift
//  ResellAI
//
//  OpenAI Service with Real Market Data Integration
//

import SwiftUI
import Foundation
import Vision

// MARK: - OpenAI Vision Service with Real Market Data Integration
class WorkingOpenAIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 6
    
    private let openAIAPIKey = Configuration.openAIKey
    private let marketDataService: MarketDataService
    
    init() {
        print("🤖 OpenAI Vision Service initialized with real market data")
        self.marketDataService = MarketDataService()
        validateConfiguration()
    }
    
    private func validateConfiguration() {
        if openAIAPIKey.isEmpty {
            print("❌ OpenAI API key missing!")
        } else {
            print("✅ OpenAI API key configured")
        }
    }
    
    // MARK: - Main Analysis Function with Real Market Data
    func analyzeItem(images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            print("❌ No images provided for analysis")
            completion(nil)
            return
        }
        
        guard !openAIAPIKey.isEmpty else {
            print("❌ OpenAI API key not configured")
            completion(nil)
            return
        }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.currentStep = 0
            self.analysisProgress = "Starting analysis..."
        }
        
        print("🔍 Starting item analysis with \(images.count) images")
        
        // Step 1: Convert images to base64
        updateProgress(1, "Processing images...")
        let base64Images = convertImagesToBase64(images)
        
        // Step 2: Product identification optimized for market search
        updateProgress(2, "Identifying product with GPT-4...")
        identifyProductForMarketSearch(base64Images: base64Images) { [weak self] identification in
            guard let self = self, let identification = identification else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    self?.analysisProgress = "Product identification failed"
                    completion(nil)
                }
                return
            }
            
            print("✅ Product identified: \(identification.exactModelName)")
            print("  • Brand: \(identification.brand)")
            print("  • Size: \(identification.size)")
            print("  • Style Code: \(identification.styleCode)")
            print("  • Confidence: \(String(format: "%.1f", identification.confidence * 100))%")
            
            // Step 3: Get real market data
            self.updateProgress(3, "Searching real eBay sold comps...")
            self.marketDataService.researchProduct(
                identification: identification,
                condition: EbayCondition.good  // Default condition, will be refined
            ) { marketAnalysis in
                
                // Step 4: Process market data
                self.updateProgress(4, "Processing market analysis...")
                
                if let marketAnalysis = marketAnalysis {
                    let soldCount = marketAnalysis.marketData.soldListings.count
                    
                    if soldCount > 0 {
                        print("✅ Real market data found:")
                        print("  • Sold Listings: \(soldCount)")
                        print("  • Average Price: $\(String(format: "%.2f", marketAnalysis.marketData.priceRange.average))")
                        print("  • Price Range: $\(String(format: "%.2f", marketAnalysis.pricingRecommendation.priceRange.min)) - $\(String(format: "%.2f", marketAnalysis.pricingRecommendation.priceRange.max))")
                        
                        self.updateProgress(5, "Found \(soldCount) real eBay sales!")
                    } else {
                        print("⚠️ No market data found - using estimates")
                        self.updateProgress(5, "No market data found - using estimates")
                    }
                    
                    // Step 5: Finalize analysis
                    self.updateProgress(6, "Finalizing analysis...")
                    
                    let finalResult = AnalysisResult(
                        identificationResult: identification,
                        marketAnalysis: marketAnalysis,
                        ebayCondition: marketAnalysis.conditionAssessment.detectedCondition,
                        ebayPricing: marketAnalysis.pricingRecommendation,
                        soldListings: marketAnalysis.marketData.soldListings,
                        confidence: marketAnalysis.confidence,
                        images: images
                    )
                    
                    DispatchQueue.main.async {
                        self.isAnalyzing = false
                        
                        if soldCount > 0 {
                            self.analysisProgress = "✅ Analysis complete with \(soldCount) real sales!"
                        } else {
                            self.analysisProgress = "⚠️ Analysis complete (no market data found)"
                        }
                        
                        print("✅ Final Analysis Results:")
                        print("  • Product: \(identification.exactModelName)")
                        print("  • Brand: \(identification.brand)")
                        print("  • Market Sales: \(soldCount)")
                        print("  • Recommended Price: $\(String(format: "%.2f", marketAnalysis.pricingRecommendation.recommendedPrice))")
                        print("  • Quick Sale: $\(String(format: "%.2f", marketAnalysis.pricingRecommendation.quickSalePrice))")
                        print("  • Market Confidence: \(String(format: "%.1f", marketAnalysis.confidence.overall * 100))%")
                        
                        completion(finalResult)
                    }
                } else {
                    // Complete fallback if market analysis fails
                    print("❌ Market analysis failed - creating basic fallback")
                    let fallbackResult = self.createFallbackAnalysis(identification: identification, images: images)
                    
                    DispatchQueue.main.async {
                        self.isAnalyzing = false
                        self.analysisProgress = "Analysis complete (fallback mode)"
                        completion(fallbackResult)
                    }
                }
            }
        }
    }
    
    // MARK: - Product Identification Optimized for Market Search
    private func identifyProductForMarketSearch(base64Images: [String], completion: @escaping (PrecisionIdentificationResult?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ Invalid OpenAI URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Optimized system prompt for market data compatibility
        let systemPrompt = """
        You are an expert product identifier focused on creating market-searchable product information for eBay sold listings research.

        CRITICAL FOR MARKET DATA SUCCESS:
        1. Use EXACT brand names as they appear on products
        2. Product names should match how items are listed on eBay
        3. Include specific model names and variations
        4. Size and colorway are crucial for accurate pricing
        5. Style codes help find exact matches

        MARKET SEARCH EXAMPLES:
        ✅ GOOD: "Nike Air Force 1 Low", "Apple iPhone 13", "Jordan 1 Bred", "Vans Authentic"
        ❌ BAD: "Basketball shoe", "Phone", "Sneaker", "Shoe"

        Return ONLY valid JSON without markdown:
        {
            "exactModelName": "Exact product name for market search",
            "brand": "Exact brand name",
            "productLine": "Product line if relevant",
            "styleVariant": "Style variant",
            "styleCode": "Style/SKU code if visible",
            "colorway": "Color description",
            "size": "Size from tags/labels",
            "category": "sneakers/clothing/electronics/accessories/home/collectibles/books/toys/sports/other",
            "subcategory": "Specific subcategory",
            "confidence": 0.95,
            "identificationDetails": ["How you identified this"],
            "alternativePossibilities": ["Other possible matches"]
        }

        Focus on creating search terms that will find real eBay sold listings.
        """
        
        // Prepare image content (use up to 3 images for speed)
        var imageContent: [[String: Any]] = []
        for base64Image in base64Images.prefix(3) {
            imageContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)",
                    "detail": "high"
                ]
            ])
        }
        
        let userPrompt = """
        Identify this product for eBay market research. Focus on:

        1. EXACT BRAND AND MODEL:
        - What specific brand is this? (look for logos, tags, labels)
        - What is the exact model name?
        - Are there style codes or SKU numbers visible?

        2. MARKET-SEARCHABLE DETAILS:
        - Size information from tags
        - Colorway/color description
        - Any specific variant names

        3. SEARCHABLE PRODUCT NAME:
        - Create a name that will find eBay sold listings
        - Use terms buyers actually search for
        - Include key identifying details

        Look carefully at all text, logos, and identifying marks in the images.
        Return ONLY the JSON object with no markdown formatting.
        """
        
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": userPrompt
                    ]
                ] + imageContent
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 800,
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating OpenAI request body: \(error)")
            completion(nil)
            return
        }
        
        print("🤖 Making OpenAI API call for product identification...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ OpenAI request error: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 OpenAI response code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("❌ OpenAI API error: HTTP \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ OpenAI error response: \(responseString)")
                    }
                    completion(nil)
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No data received from OpenAI")
                completion(nil)
                return
            }
            
            self?.processOpenAIResponse(data: data, completion: completion)
            
        }.resume()
    }
    
    // MARK: - Process OpenAI Response
    private func processOpenAIResponse(data: Data, completion: @escaping (PrecisionIdentificationResult?) -> Void) {
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = response.choices.first?.message.content else {
                print("❌ No content in OpenAI response")
                completion(nil)
                return
            }
            
            print("🤖 OpenAI identification response received")
            
            // Clean and parse JSON response
            let cleanedContent = cleanMarkdownFromJSON(content)
            
            if let jsonData = cleanedContent.data(using: .utf8) {
                do {
                    let productData = try JSONDecoder().decode(OpenAIProductIdentification.self, from: jsonData)
                    
                    // Create identification result
                    let identification = PrecisionIdentificationResult(
                        exactModelName: productData.exactModelName,
                        brand: productData.brand,
                        productLine: productData.productLine,
                        styleVariant: productData.styleVariant,
                        styleCode: productData.styleCode ?? "",
                        colorway: productData.colorway,
                        size: productData.size,
                        category: ProductCategory(rawValue: productData.category) ?? .other,
                        subcategory: productData.subcategory,
                        identificationMethod: .visualAndText,
                        confidence: productData.confidence,
                        identificationDetails: productData.identificationDetails,
                        alternativePossibilities: productData.alternativePossibilities
                    )
                    
                    print("✅ Product identification successful:")
                    print("  • Name: \(identification.exactModelName)")
                    print("  • Brand: \(identification.brand)")
                    print("  • Style Code: \(identification.styleCode)")
                    print("  • Size: \(identification.size)")
                    print("  • Colorway: \(identification.colorway)")
                    print("  • Category: \(identification.category.rawValue)")
                    print("  • Confidence: \(String(format: "%.1f", identification.confidence * 100))%")
                    
                    completion(identification)
                    
                } catch {
                    print("❌ Error parsing OpenAI product data: \(error)")
                    print("🔍 Raw content: \(cleanedContent)")
                    
                    // Try to create a basic identification from partial data
                    if let partialIdentification = parsePartialIdentification(from: cleanedContent) {
                        print("✅ Partial identification created")
                        completion(partialIdentification)
                    } else {
                        print("❌ Creating fallback identification")
                        completion(createFallbackIdentification())
                    }
                }
            } else {
                print("❌ Could not convert OpenAI content to data")
                completion(createFallbackIdentification())
            }
            
        } catch {
            print("❌ OpenAI response parsing error: \(error)")
            completion(createFallbackIdentification())
        }
    }
    
    // MARK: - Barcode Analysis
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        updateProgress(1, "Looking up barcode...")
        
        // If we have images, do full analysis with barcode enhancement
        if !images.isEmpty {
            analyzeItem(images: images) { result in
                if let result = result {
                    // Enhance with barcode information
                    var enhancedIdentification = result.identificationResult
                    if enhancedIdentification.styleCode.isEmpty {
                        enhancedIdentification = PrecisionIdentificationResult(
                            exactModelName: enhancedIdentification.exactModelName,
                            brand: enhancedIdentification.brand,
                            productLine: enhancedIdentification.productLine,
                            styleVariant: enhancedIdentification.styleVariant,
                            styleCode: barcode,
                            colorway: enhancedIdentification.colorway,
                            size: enhancedIdentification.size,
                            category: enhancedIdentification.category,
                            subcategory: enhancedIdentification.subcategory,
                            identificationMethod: enhancedIdentification.identificationMethod,
                            confidence: enhancedIdentification.confidence,
                            identificationDetails: enhancedIdentification.identificationDetails + ["Barcode: \(barcode)"],
                            alternativePossibilities: enhancedIdentification.alternativePossibilities
                        )
                    }
                    
                    let enhancedResult = AnalysisResult(
                        identificationResult: enhancedIdentification,
                        marketAnalysis: result.marketAnalysis,
                        ebayCondition: result.ebayCondition,
                        ebayPricing: result.ebayPricing,
                        soldListings: result.soldListings,
                        confidence: result.confidence,
                        images: result.images
                    )
                    completion(enhancedResult)
                } else {
                    completion(nil)
                }
            }
        } else {
            // Barcode-only lookup
            let barcodeIdentification = PrecisionIdentificationResult(
                exactModelName: "Barcode Product",
                brand: "Unknown",
                productLine: "",
                styleVariant: "",
                styleCode: barcode,
                colorway: "",
                size: "",
                category: .other,
                subcategory: "",
                identificationMethod: .textOnly,
                confidence: 0.6,
                identificationDetails: ["Identified by barcode: \(barcode)"],
                alternativePossibilities: []
            )
            
            marketDataService.researchProduct(identification: barcodeIdentification, condition: EbayCondition.good) { marketAnalysis in
                let result = self.createFallbackAnalysis(identification: barcodeIdentification, images: [])
                completion(result)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateProgress(_ step: Int, _ message: String) {
        DispatchQueue.main.async {
            self.currentStep = step
            self.analysisProgress = message
        }
        print("🔄 Step \(step)/\(totalSteps): \(message)")
    }
    
    private func convertImagesToBase64(_ images: [UIImage]) -> [String] {
        return images.compactMap { image in
            let resizedImage = resizeImage(image, to: CGSize(width: 1024, height: 1024))
            return resizedImage.jpegData(compressionQuality: 0.8)?.base64EncodedString()
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func cleanMarkdownFromJSON(_ content: String) -> String {
        var cleaned = content
        
        // Remove markdown code blocks
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```JSON", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        
        // Extract JSON between first { and last }
        if let jsonStart = cleaned.firstIndex(of: "{"),
           let jsonEnd = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[jsonStart...jsonEnd])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parsePartialIdentification(from json: String) -> PrecisionIdentificationResult? {
        // Try to extract basic information using regex
        var exactModelName = "Unknown Product"
        var brand = ""
        var size = ""
        var colorway = ""
        var category = "other"
        var styleCode = ""
        
        // Extract values using simple pattern matching
        if let modelRange = json.range(of: "\"exactModelName\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            exactModelName = extractQuotedValue(from: String(json[modelRange]))
        }
        
        if let brandRange = json.range(of: "\"brand\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            brand = extractQuotedValue(from: String(json[brandRange]))
        }
        
        if let sizeRange = json.range(of: "\"size\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            size = extractQuotedValue(from: String(json[sizeRange]))
        }
        
        if let colorRange = json.range(of: "\"colorway\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            colorway = extractQuotedValue(from: String(json[colorRange]))
        }
        
        if let categoryRange = json.range(of: "\"category\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            category = extractQuotedValue(from: String(json[categoryRange]))
        }
        
        if let styleRange = json.range(of: "\"styleCode\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            styleCode = extractQuotedValue(from: String(json[styleRange]))
        }
        
        return PrecisionIdentificationResult(
            exactModelName: exactModelName,
            brand: brand,
            productLine: "",
            styleVariant: "",
            styleCode: styleCode,
            colorway: colorway,
            size: size,
            category: ProductCategory(rawValue: category) ?? .other,
            subcategory: "",
            identificationMethod: .visualOnly,
            confidence: 0.7,
            identificationDetails: ["Extracted from partial OpenAI response"],
            alternativePossibilities: []
        )
    }
    
    private func extractQuotedValue(from match: String) -> String {
        if let colonIndex = match.firstIndex(of: ":"),
           let startQuote = match.firstIndex(of: "\"", range: colonIndex..<match.endIndex),
           let endQuote = match.lastIndex(of: "\"") {
            let startIndex = match.index(after: startQuote)
            if startIndex < endQuote {
                return String(match[startIndex..<endQuote])
            }
        }
        return ""
    }
    
    private func createFallbackIdentification() -> PrecisionIdentificationResult {
        return PrecisionIdentificationResult(
            exactModelName: "Product",
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
            identificationDetails: ["Basic visual analysis - limited information available"],
            alternativePossibilities: []
        )
    }
    
    private func createFallbackAnalysis(identification: PrecisionIdentificationResult, images: [UIImage]) -> AnalysisResult {
        let basePrice = estimatePrice(for: identification)
        
        let soldListings: [EbaySoldListing] = []
        
        let priceRange = EbayPriceRange(
            newWithTags: basePrice * 1.0,
            newWithoutTags: basePrice * 0.95,
            likeNew: basePrice * 0.85,
            excellent: basePrice * 0.75,
            veryGood: basePrice * 0.65,
            good: basePrice * 0.50,
            acceptable: basePrice * 0.35,
            average: basePrice * 0.75,
            soldCount: 0,
            dateRange: "No market data"
        )
        
        let marketData = EbayMarketData(
            soldListings: soldListings,
            priceRange: priceRange,
            marketTrend: MarketTrend(direction: .stable, strength: .moderate, timeframe: "Unknown", seasonalFactors: []),
            demandIndicators: DemandIndicators(watchersPerListing: 0, viewsPerListing: 0, timeToSell: .normal, searchVolume: .low),
            competitionLevel: .low,
            lastUpdated: Date()
        )
        
        let condition = EbayConditionAssessment(
            detectedCondition: EbayCondition.good,
            conditionConfidence: 0.7,
            conditionFactors: [],
            conditionNotes: ["No market data found", "Price estimated based on category"],
            photographyRecommendations: ["Take clear photos for better analysis"]
        )
        
        let pricing = EbayPricingRecommendation(
            recommendedPrice: basePrice * 0.75,
            priceRange: (min: basePrice * 0.6, max: basePrice * 0.9),
            competitivePrice: basePrice * 0.72,
            quickSalePrice: basePrice * 0.65,
            maxProfitPrice: basePrice * 0.85,
            pricingStrategy: .discount,
            priceJustification: ["Estimated price - no market data available"]
        )
        
        let listingStrategy = EbayListingStrategy(
            recommendedTitle: "\(identification.brand) \(identification.exactModelName)".trimmingCharacters(in: .whitespaces),
            keywordOptimization: [identification.brand, identification.exactModelName].filter { !$0.isEmpty },
            categoryPath: "Everything Else",
            listingFormat: .buyItNow,
            photographyChecklist: ["Take detailed photos", "Show all angles", "Include brand tags"],
            descriptionTemplate: "Item as shown in photos. See description for details."
        )
        
        let confidence = MarketConfidence(
            overall: identification.confidence * 0.6,
            identification: identification.confidence,
            condition: 0.7,
            pricing: 0.3,
            dataQuality: .insufficient
        )
        
        let marketAnalysis = MarketAnalysisResult(
            identifiedProduct: identification,
            marketData: marketData,
            conditionAssessment: condition,
            pricingRecommendation: pricing,
            listingStrategy: listingStrategy,
            confidence: confidence
        )
        
        return AnalysisResult(
            identificationResult: identification,
            marketAnalysis: marketAnalysis,
            ebayCondition: condition.detectedCondition,
            ebayPricing: pricing,
            soldListings: soldListings,
            confidence: confidence,
            images: images
        )
    }
    
    private func estimatePrice(for identification: PrecisionIdentificationResult) -> Double {
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

// MARK: - Extension for String Range Operations
extension String {
    func firstIndex(of character: Character, range: Range<String.Index>) -> String.Index? {
        return self[range].firstIndex(of: character).map {
            self.index(self.startIndex, offsetBy: self.distance(from: self.startIndex, to: $0))
        }
    }
}

// MARK: - OpenAI API Response Models
struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}

struct OpenAIProductIdentification: Codable {
    let exactModelName: String
    let brand: String
    let productLine: String
    let styleVariant: String
    let styleCode: String?
    let colorway: String
    let size: String
    let category: String
    let subcategory: String
    let confidence: Double
    let identificationDetails: [String]
    let alternativePossibilities: [String]
}
