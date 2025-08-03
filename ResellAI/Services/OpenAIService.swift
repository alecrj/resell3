//
//  OpenAIService.swift
//  ResellAI
//
//  Fixed OpenAI Service with New MarketDataService
//

import SwiftUI
import Foundation
import Vision

// MARK: - Fixed OpenAI Vision Service with Production Market Data
class WorkingOpenAIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    
    private let openAIAPIKey = Configuration.openAIKey
    private let marketDataService: MarketDataService
    
    init() {
        print("🤖 OpenAI Vision Service initialized with production market data")
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
    
    // MARK: - Main Analysis Function with Production Market Data
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
        
        // Step 1: Convert images to base64
        updateProgress(1, "Processing images...")
        let base64Images = convertImagesToBase64(images)
        
        // Step 2: Product identification optimized for market data
        updateProgress(2, "Identifying product...")
        identifyProductForMarketSearch(base64Images: base64Images) { [weak self] identification in
            guard let self = self, let identification = identification else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            // Step 3-6: Market research with new service
            self.updateProgress(3, "Searching market data...")
            self.marketDataService.researchProduct(
                identification: identification,
                condition: EbayCondition.good
            ) { marketAnalysis in
                
                guard let marketAnalysis = marketAnalysis else {
                    // Fallback analysis if market research fails
                    let fallbackResult = self.createFallbackAnalysis(identification: identification, images: images)
                    DispatchQueue.main.async {
                        self.isAnalyzing = false
                        self.analysisProgress = "Analysis complete (limited data)"
                        completion(fallbackResult)
                    }
                    return
                }
                
                // Step 7: Process market data
                self.updateProgress(7, "Processing market data...")
                
                // Step 8: Compile final result
                self.updateProgress(8, "Finalizing analysis...")
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
                    self.analysisProgress = "Analysis complete with \(marketAnalysis.marketData.soldListings.count) market data points!"
                    
                    print("✅ Analysis complete:")
                    print("  • Product: \(identification.exactModelName)")
                    print("  • Brand: \(identification.brand)")
                    print("  • Market Data: \(marketAnalysis.marketData.soldListings.count) sales")
                    print("  • Recommended Price: $\(String(format: "%.2f", marketAnalysis.pricingRecommendation.recommendedPrice))")
                    print("  • Market Confidence: \(String(format: "%.1f", marketAnalysis.confidence.overall * 100))%")
                    
                    completion(finalResult)
                }
            }
        }
    }
    
    // MARK: - Product Identification for Market Search
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
        You are an expert product identifier that creates market-searchable product information. Your goal is to identify products in a way that will find matches across multiple market data sources.

        CRITICAL FOR MARKET DATA SUCCESS:
        1. Use EXACT brand names as they appear on products
        2. Product names should be specific but searchable
        3. Include style codes when clearly visible
        4. Size information is crucial for accurate pricing
        5. Focus on terms that will return market data results

        MARKET DATA EXAMPLES:
        ✅ GOOD: "Nike Air Force 1 Low", "Apple iPhone 13", "Jordan 1 Bred"
        ❌ BAD: "Basketball shoe", "Phone", "Sneaker"

        Return ONLY valid JSON without markdown:
        {
            "exactModelName": "Specific searchable product name",
            "brand": "Exact brand name",
            "productLine": "Product line if relevant",
            "styleVariant": "Variant if needed",
            "styleCode": "Style/SKU code if visible",
            "colorway": "Color description",
            "size": "Size if visible on tags",
            "category": "sneakers/clothing/electronics/accessories/home/collectibles/books/toys/sports/other",
            "subcategory": "Specific subcategory",
            "confidence": 0.95,
            "identificationDetails": ["How you identified this product"],
            "alternativePossibilities": ["Other possible matches"]
        }

        Focus on product details that will help find accurate market pricing data.
        """
        
        // Prepare image content
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
        Identify this product for market data search. Focus on:

        1. EXACT PRODUCT IDENTIFICATION:
        - What is the specific brand and model?
        - Are there any style codes or SKU numbers visible?
        - What size is shown on tags or labels?
        - What is the exact colorway/style?

        2. MARKET DATA COMPATIBILITY:
        - Use terms that will find pricing data
        - Be specific enough for accurate matches
        - Include details that affect market value

        3. KEY INFORMATION FOR PRICING:
        - Brand name (exactly as shown)
        - Model/product line
        - Size (crucial for accurate pricing)
        - Condition indicators
        - Style codes if visible

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
            "max_tokens": 1000,
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
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
                    
                    print("✅ Product identification:")
                    print("  • Name: \(identification.exactModelName)")
                    print("  • Brand: \(identification.brand)")
                    print("  • Style Code: \(identification.styleCode)")
                    print("  • Size: \(identification.size)")
                    print("  • Colorway: \(identification.colorway)")
                    print("  • Confidence: \(String(format: "%.1f", identification.confidence * 100))%")
                    
                    completion(identification)
                    
                } catch {
                    print("❌ Error parsing OpenAI product data: \(error)")
                    print("🔍 Attempting to parse partial content...")
                    
                    if let partialIdentification = parsePartialIdentification(from: cleanedContent) {
                        print("✅ Partial identification successful")
                        completion(partialIdentification)
                    } else {
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
        
        if !images.isEmpty {
            analyzeItem(images: images) { result in
                if let result = result {
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
            marketDataService.researchProduct(identification: barcodeIdentification, condition: EbayCondition.good) { marketAnalysis in
                let result = self.createFallbackAnalysis(identification: barcodeIdentification, images: [])
                completion(result)
            }
        }
    }
    
    // MARK: - Helper Methods (unchanged from original)
    private func updateProgress(_ step: Int, _ message: String) {
        DispatchQueue.main.async {
            self.currentStep = step
            self.analysisProgress = message
        }
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
        
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```JSON", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        
        if let jsonStart = cleaned.firstIndex(of: "{"),
           let jsonEnd = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[jsonStart...jsonEnd])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parsePartialIdentification(from json: String) -> PrecisionIdentificationResult? {
        var exactModelName = "Unknown Product"
        var brand = ""
        var size = ""
        var colorway = ""
        var category = "other"
        var styleCode = ""
        
        // Extract using regex patterns
        if let modelRange = json.range(of: "\"exactModelName\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            exactModelName = extractValue(from: String(json[modelRange]))
        }
        
        if let brandRange = json.range(of: "\"brand\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            brand = extractValue(from: String(json[brandRange]))
        }
        
        if let sizeRange = json.range(of: "\"size\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            size = extractValue(from: String(json[sizeRange]))
        }
        
        if let colorRange = json.range(of: "\"colorway\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            colorway = extractValue(from: String(json[colorRange]))
        }
        
        if let categoryRange = json.range(of: "\"category\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            category = extractValue(from: String(json[categoryRange]))
        }
        
        if let styleRange = json.range(of: "\"styleCode\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            styleCode = extractValue(from: String(json[styleRange]))
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
    
    private func extractValue(from match: String) -> String {
        if let colonIndex = match.firstIndex(of: ":"),
           let startQuote = match.firstIndex(of: "\"", after: colonIndex),
           let endQuote = match.lastIndex(of: "\"") {
            let startIndex = match.index(after: startQuote)
            return String(match[startIndex..<endQuote])
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
            dateRange: "No data available"
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
        } else if brand.contains("apple") {
            return 350.0
        } else if brand.contains("supreme") {
            return 200.0
        } else if brand.contains("champion") {
            return category == .clothing ? 25.0 : 30.0
        }
        
        switch category {
        case .sneakers: return 80.0
        case .electronics: return 150.0
        case .clothing: return 30.0
        case .accessories: return 35.0
        default: return 40.0
        }
    }
}

// MARK: - Extension for String.firstIndex
extension String {
    func firstIndex(of character: Character, after index: String.Index) -> String.Index? {
        return self[self.index(after: index)...].firstIndex(of: character).map {
            self.index($0, offsetBy: 0)
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
