//
//  OpenAIService.swift
//  ResellAI
//
//  Fixed OpenAI Service with Better eBay Search Keywords
//

import SwiftUI
import Foundation
import Vision

// MARK: - Fixed OpenAI Vision Service with eBay-Optimized Keywords
class WorkingOpenAIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    
    private let openAIAPIKey = Configuration.openAIKey
    private let marketResearchService: MarketResearchService
    
    init() {
        print("🤖 OpenAI Vision Service initialized with eBay-optimized keywords")
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
    
    // MARK: - Main Analysis Function with eBay Search Optimization
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
        
        // Step 2: Product identification optimized for eBay search
        updateProgress(2, "Identifying product for eBay search...")
        identifyProductForEbaySearch(base64Images: base64Images) { [weak self] identification in
            guard let self = self, let identification = identification else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            // Step 3-6: eBay market research with optimized keywords
            self.updateProgress(3, "Searching eBay with optimized keywords...")
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
    
    // MARK: - Product Identification Optimized for eBay Search
    private func identifyProductForEbaySearch(base64Images: [String], completion: @escaping (PrecisionIdentificationResult?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ Invalid OpenAI URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Optimized system prompt for eBay search compatibility
        let systemPrompt = """
        You are an expert product identifier that creates eBay-compatible search terms. Your goal is to identify products in a way that will find exact matches on eBay.

        CRITICAL FOR EBAY SEARCH SUCCESS:
        1. Use SIMPLE, COMMON terms that people actually search for on eBay
        2. Brand names should be exactly as they appear on eBay (Nike, not "nike" or "NIKE")
        3. Product names should be simplified and searchable (avoid complex model names)
        4. Focus on terms that will return results, not overly specific details
        5. Size information is crucial for clothing/shoes
        6. Avoid marketing language - use practical terms

        eBay SEARCH EXAMPLES:
        ✅ GOOD: "Champion hoodie", "Nike Air Force 1", "iPhone 13"
        ❌ BAD: "Champion Powerblend Fleece Full-Zip Performance Hoodie", "Nike Air Force 1 Low '07 White/White Classic Basketball Shoe"

        Return ONLY valid JSON without markdown:
        {
            "exactModelName": "Simple searchable product name (2-4 words max)",
            "brand": "Exact brand name as it appears on eBay",
            "productLine": "Simple product line if relevant",
            "styleVariant": "Basic variant if needed",
            "styleCode": "Only if clearly visible and searchable",
            "colorway": "Simple color description",
            "size": "Size if visible on tags",
            "category": "sneakers/clothing/electronics/accessories/home/collectibles/books/toys/sports/other",
            "subcategory": "Simple subcategory",
            "confidence": 0.95,
            "identificationDetails": ["What you found that led to this identification"],
            "alternativePossibilities": ["Other simple search terms that might work"]
        }

        EXAMPLES of eBay-optimized identification:
        - Champion hoodie → exactModelName="Champion Hoodie", brand="Champion"
        - Nike shoes → exactModelName="Nike Air Force 1", brand="Nike"  
        - iPhone → exactModelName="iPhone 13", brand="Apple"

        Focus on what buyers actually type into eBay search, not technical specifications.
        """
        
        // Prepare image content
        var imageContent: [[String: Any]] = []
        for base64Image in base64Images.prefix(3) { // Reduced to 3 images for faster processing
            imageContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)",
                    "detail": "high"
                ]
            ])
        }
        
        let userPrompt = """
        Identify this product for eBay search. Focus on:

        1. SIMPLE SEARCHABLE TERMS:
        - What would someone type into eBay to find this exact item?
        - Use common terms, not marketing language
        - Keep product names short and practical

        2. KEY INFORMATION FOR EBAY:
        - Brand name (exactly as it appears on eBay)
        - Basic product type (hoodie, shoes, phone, etc.)
        - Size if visible (crucial for clothing/shoes)
        - Simple color description
        - Style code only if clearly visible

        3. THINK LIKE AN EBAY BUYER:
        - What search terms would find this item?
        - Avoid overly complex model names
        - Use terms that get results, not perfect accuracy

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
            "max_tokens": 1000, // Reduced for simpler responses
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
            completion(nil)
            return
        }
        
        print("🤖 Making OpenAI API call for eBay-optimized identification...")
        
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
            
            self?.processOpenAIResponseForEbay(data: data, completion: completion)
            
        }.resume()
    }
    
    // MARK: - Process OpenAI Response for eBay Search
    private func processOpenAIResponseForEbay(data: Data, completion: @escaping (PrecisionIdentificationResult?) -> Void) {
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
                    
                    // Create simplified identification for better eBay search
                    let identification = PrecisionIdentificationResult(
                        exactModelName: simplifyProductName(productData.exactModelName),
                        brand: productData.brand,
                        productLine: productData.productLine,
                        styleVariant: productData.styleVariant,
                        styleCode: productData.styleCode ?? "",
                        colorway: simplifyColorway(productData.colorway),
                        size: productData.size,
                        category: ProductCategory(rawValue: productData.category) ?? .other,
                        subcategory: productData.subcategory,
                        identificationMethod: .visualAndText,
                        confidence: productData.confidence,
                        identificationDetails: productData.identificationDetails,
                        alternativePossibilities: productData.alternativePossibilities
                    )
                    
                    print("✅ eBay-optimized identification:")
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
    
    // MARK: - Simplify Product Names for eBay Search
    private func simplifyProductName(_ name: String) -> String {
        // Remove marketing terms and simplify
        var simplified = name
        
        // Remove common marketing words
        let marketingWords = ["Powerblend", "Performance", "Premium", "Ultimate", "Professional", "Advanced", "Classic", "Original", "Authentic", "Official"]
        for word in marketingWords {
            simplified = simplified.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        
        // Clean up extra spaces
        simplified = simplified.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        
        // Limit to 4 words max for better eBay search
        let words = simplified.components(separatedBy: " ").filter { !$0.isEmpty }
        let limitedWords = Array(words.prefix(4))
        
        return limitedWords.joined(separator: " ")
    }
    
    private func simplifyColorway(_ colorway: String) -> String {
        // Simplify color descriptions
        let colorMappings = [
            "Oxford Gray": "Gray",
            "Heather Gray": "Gray",
            "True White": "White",
            "Classic Black": "Black",
            "Navy Blue": "Navy",
            "Royal Blue": "Blue"
        ]
        
        for (complex, simple) in colorMappings {
            if colorway.contains(complex) {
                return simple
            }
        }
        
        return colorway
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
            marketResearchService.researchProduct(identification: barcodeIdentification, condition: EbayCondition.good) { marketAnalysis in
                let result = self.createFallbackAnalysis(identification: barcodeIdentification, images: [])
                completion(result)
            }
        }
    }
    
    // MARK: - Helper Methods (same as before)
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
            exactModelName: simplifyProductName(exactModelName),
            brand: brand,
            productLine: "",
            styleVariant: "",
            styleCode: styleCode,
            colorway: simplifyColorway(colorway),
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
