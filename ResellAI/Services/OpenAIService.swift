//
//  OpenAIService.swift
//  ResellAI
//
//  OpenAI Vision API Service with Real eBay Comp Integration - Fixed
//

import SwiftUI
import Foundation
import Vision

// MARK: - OpenAI Vision Service with Real Market Data (Fixed)
class WorkingOpenAIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    
    private let openAIAPIKey = Configuration.openAIKey
    private let marketResearchService: MarketResearchService
    
    init() {
        print("🤖 OpenAI Vision Service initialized with real eBay integration")
        self.marketResearchService = MarketResearchService()
        validateConfiguration()
    }
    
    private func validateConfiguration() {
        if openAIAPIKey.isEmpty {
            print("❌ OpenAI API key missing!")
        } else {
            print("✅ OpenAI API key configured")
        }
    }
    
    // MARK: - Main Analysis Function with Real eBay Data
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
        
        // Step 2: Product identification with AI vision
        updateProgress(2, "Identifying product with AI vision...")
        identifyProductWithPrecision(base64Images: base64Images) { [weak self] identification in
            guard let self = self, let identification = identification else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            // Step 3-6: Real eBay market research
            self.updateProgress(3, "Searching eBay for exact matches...")
            self.marketResearchService.researchProduct(
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
                
                // Step 7: Process real market data
                self.updateProgress(7, "Processing market data...")
                
                // Step 8: Compile final result with real eBay comps
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
                    self.analysisProgress = "Analysis complete with \(marketAnalysis.marketData.soldListings.count) sold comps!"
                    
                    print("✅ Analysis complete:")
                    print("  • Product: \(identification.exactModelName)")
                    print("  • Brand: \(identification.brand)")
                    print("  • Sold Comps: \(marketAnalysis.marketData.soldListings.count)")
                    print("  • Recommended Price: $\(String(format: "%.2f", marketAnalysis.pricingRecommendation.recommendedPrice))")
                    print("  • Market Confidence: \(String(format: "%.1f", marketAnalysis.confidence.overall * 100))%")
                    
                    completion(finalResult)
                }
            }
        }
    }
    
    // MARK: - Product Identification with AI Vision (Enhanced)
    private func identifyProductWithPrecision(base64Images: [String], completion: @escaping (PrecisionIdentificationResult?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ Invalid OpenAI URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Enhanced system prompt for better eBay comp matching
        let systemPrompt = """
        You are an expert product identifier specializing in items for resale. Your identification will be used to search eBay sold listings for pricing.

        CRITICAL: Focus on details that will help find exact eBay matches:
        1. EXACT model names, style codes, SKUs (these are crucial for eBay searches)
        2. Brand identification from any visible logos, tags, or labels
        3. Specific product lines and variants
        4. Size information from tags (essential for shoes/clothing)
        5. Color/colorway names (not just "blue" - be specific like "Royal Blue" or "Navy")
        6. Any numbers, codes, or text visible on the product
        7. Unique identifying features that distinguish this from similar items

        Your identification will generate eBay search queries like:
        - "[brand] [exact model name]"
        - "[style code]"
        - "[brand] [product line] [size] [colorway]"

        Return ONLY valid JSON without markdown formatting:
        {
            "exactModelName": "Most specific product name that would appear in eBay listings",
            "brand": "Exact brand name",
            "productLine": "Product line/series if applicable",
            "styleVariant": "Specific style variant or version",
            "styleCode": "Any style/SKU/model code visible (crucial for eBay matching)",
            "colorway": "Specific color description (not generic colors)",
            "size": "Size if visible on tags/labels",
            "category": "sneakers/clothing/electronics/accessories/home/collectibles/books/toys/sports/other",
            "subcategory": "Most specific subcategory",
            "confidence": 0.95,
            "identificationDetails": ["Specific features found", "Text/codes read", "Brand markings seen"],
            "alternativePossibilities": ["Other similar products if uncertain"]
        }

        EXAMPLES of good identification:
        - Nike shoes: exactModelName="Air Force 1 Low '07", styleCode="315122-111", colorway="White/White"
        - Guess shirt: exactModelName="Los Angeles Triangle Logo Tee", brand="Guess"
        - Electronics: exactModelName="iPhone 13 Pro", styleCode="A2483", size="128GB"

        Be extremely specific to help find exact eBay matches.
        """
        
        // Prepare image content for OpenAI
        var imageContent: [[String: Any]] = []
        for base64Image in base64Images.prefix(4) {
            imageContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)",
                    "detail": "high"
                ]
            ])
        }
        
        let userPrompt = """
        Identify this product for eBay resale research. Look carefully for:
        
        PRIORITY 1 - Text/Numbers/Codes:
        - Style codes, SKUs, model numbers
        - Brand names on tags or labels
        - Size information on tags
        - Any text or numbers on the product
        
        PRIORITY 2 - Visual Identification:
        - Brand logos and distinctive design elements
        - Specific product features that distinguish it
        - Color patterns and colorway names
        - Construction details and materials
        
        Focus on details that would help someone find this exact item on eBay.
        
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
            "max_tokens": 1500,
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
            completion(nil)
            return
        }
        
        print("🤖 Making OpenAI Vision API call for product identification...")
        
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
            
            print("🤖 Raw OpenAI identification response received")
            
            // Clean and parse JSON response
            let cleanedContent = cleanMarkdownFromJSON(content)
            
            if let jsonData = cleanedContent.data(using: .utf8) {
                do {
                    let productData = try JSONDecoder().decode(OpenAIProductIdentification.self, from: jsonData)
                    
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
                    
                    print("✅ Product identified successfully:")
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
                    
                    // Try to extract partial information
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
    
    // MARK: - Barcode Analysis with Real Market Research
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        updateProgress(1, "Looking up barcode...")
        
        // Create identification from barcode
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
        
        // If we have images, analyze them too
        if !images.isEmpty {
            analyzeItem(images: images) { result in
                // Enhance the result with barcode information
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
                    
                    // Create new result with enhanced identification
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
            // Barcode-only analysis
            marketResearchService.researchProduct(identification: barcodeIdentification, condition: EbayCondition.good) { marketAnalysis in
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
        
        // Extract JSON object
        if let jsonStart = cleaned.firstIndex(of: "{"),
           let jsonEnd = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[jsonStart...jsonEnd])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parsePartialIdentification(from json: String) -> PrecisionIdentificationResult? {
        // Try to extract fields manually if JSON parsing fails
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
        // Estimate base pricing
        let basePrice = estimatePrice(for: identification)
        
        // Create empty sold listings for fallback
        let soldListings: [EbaySoldListing] = []
        
        // Create basic price range
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
        
        // Create minimal market data
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
            conditionNotes: ["No sold comps found", "Price estimated based on category"],
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
        
        // Brand-specific estimates
        if brand.contains("nike") || brand.contains("jordan") {
            return category == .sneakers ? 120.0 : 45.0
        } else if brand.contains("adidas") {
            return category == .sneakers ? 100.0 : 40.0
        } else if brand.contains("apple") {
            return 350.0
        } else if brand.contains("supreme") {
            return 200.0
        }
        
        // Category-based estimates
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
