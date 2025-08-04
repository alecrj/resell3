//
//  OpenAIService.swift
//  ResellAI
//
//  OpenAI Service without AIService redeclaration
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
            completion(nil)
            return
        }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.currentStep = 0
            self.analysisProgress = "Starting analysis..."
        }
        
        // Step 1: Visual identification
        updateProgress(step: 0, message: "Analyzing images...")
        performVisualIdentification(images: images) { identificationResult in
            guard let identification = identificationResult else {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            // Step 2: Market research
            self.updateProgress(step: 1, message: "Researching market data...")
            self.marketDataService.searchMarketData(for: identification.productName) { marketData in
                
                // Step 3: Price analysis
                self.updateProgress(step: 2, message: "Analyzing pricing...")
                let pricingRecommendation = self.calculatePricing(
                    identification: identification,
                    marketData: marketData
                )
                
                // Step 4: Competition analysis
                self.updateProgress(step: 3, message: "Analyzing competition...")
                let competitionLevel = self.analyzeCompetition(marketData: marketData)
                
                // Step 5: Generate listing recommendations
                self.updateProgress(step: 4, message: "Generating recommendations...")
                let listingTips = self.generateListingTips(
                    identification: identification,
                    marketData: marketData,
                    competition: competitionLevel
                )
                
                // Step 6: Finalize analysis
                self.updateProgress(step: 5, message: "Finalizing analysis...")
                
                let analysisResult = AnalysisResult(
                    productName: identification.productName,
                    category: identification.category,
                    brand: identification.brand,
                    model: identification.model,
                    size: identification.size ?? "",
                    color: identification.color ?? "",
                    condition: identification.condition,
                    estimatedValue: pricingRecommendation.suggestedPrice,
                    confidence: identification.confidence,
                    description: self.generateDescription(identification: identification),
                    suggestedTitle: self.generateTitle(identification: identification),
                    suggestedKeywords: self.generateKeywords(identification: identification),
                    marketData: marketData,
                    competitionLevel: competitionLevel,
                    pricingStrategy: pricingRecommendation.strategy,
                    listingTips: listingTips,
                    identificationResult: identification
                )
                
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.analysisProgress = "Analysis complete"
                    completion(analysisResult)
                }
            }
        }
    }
    
    private func updateProgress(step: Int, message: String) {
        DispatchQueue.main.async {
            self.currentStep = step
            self.analysisProgress = message
        }
    }
    
    // MARK: - Visual Identification
    private func performVisualIdentification(images: [UIImage], completion: @escaping (PrecisionIdentificationResult?) -> Void) {
        guard let firstImage = images.first,
              let imageData = firstImage.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let messages = [
            [
                "role": "system",
                "content": """
                You are an expert product identifier for resellers. Analyze the image and provide detailed product information in JSON format.
                Focus on: exact product name, brand, model, condition, category, size, color, year if applicable.
                Be very specific with model names and variations.
                """
            ],
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": "Identify this product with detailed specifications:"],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 1000,
            "temperature": 0.3
        ]
        
        performOpenAIRequest(requestBody: requestBody) { response in
            if let content = response?["choices"] as? [[String: Any]],
               let firstChoice = content.first,
               let message = firstChoice["message"] as? [String: Any],
               let text = message["content"] as? String {
                
                let identification = self.parseIdentificationResponse(text)
                completion(identification)
            } else {
                // Fallback identification
                let fallbackResult = PrecisionIdentificationResult(
                    productName: "Unidentified Item",
                    brand: "Unknown",
                    model: "",
                    category: ProductCategory.other.rawValue,
                    condition: .good,
                    confidence: 0.5
                )
                completion(fallbackResult)
            }
        }
    }
    
    private func parseIdentificationResponse(_ text: String) -> PrecisionIdentificationResult {
        // Try to parse JSON response
        if let jsonData = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            let productName = json["product_name"] as? String ?? "Unknown Item"
            let brand = json["brand"] as? String ?? ""
            let model = json["model"] as? String ?? ""
            let category = json["category"] as? String ?? ProductCategory.other.rawValue
            let conditionString = json["condition"] as? String ?? "Good"
            let confidence = json["confidence"] as? Double ?? 0.7
            
            let condition = EbayCondition.allCases.first { $0.rawValue.lowercased() == conditionString.lowercased() } ?? .good
            
            return PrecisionIdentificationResult(
                productName: productName,
                brand: brand,
                model: model,
                category: category,
                condition: condition,
                confidence: confidence,
                size: json["size"] as? String,
                color: json["color"] as? String,
                year: json["year"] as? String,
                styleCode: json["style_code"] as? String
            )
        }
        
        // Fallback parsing
        return PrecisionIdentificationResult(
            productName: "Item from Photo",
            brand: "Unknown",
            model: "",
            category: ProductCategory.other.rawValue,
            condition: .good,
            confidence: 0.6
        )
    }
    
    // MARK: - Helper Functions
    private func calculatePricing(identification: PrecisionIdentificationResult, marketData: MarketData?) -> EbayPricingRecommendation {
        let basePrice = marketData?.averagePrice ?? 50.0
        let conditionMultiplier = identification.condition.priceMultiplier
        let suggestedPrice = basePrice * conditionMultiplier
        
        let strategy: PricingStrategy = {
            guard let marketData = marketData else { return .market }
            
            if marketData.soldInLast30Days > 20 {
                return .quickSale
            } else if marketData.soldInLast30Days < 5 {
                return .premium
            } else {
                return .market
            }
        }()
        
        return EbayPricingRecommendation(
            suggestedPrice: suggestedPrice,
            strategy: strategy,
            competitionLevel: .moderate,
            priceRange: marketData?.priceRange,
            confidence: identification.confidence
        )
    }
    
    private func analyzeCompetition(marketData: MarketData?) -> CompetitionLevel {
        guard let marketData = marketData else { return .moderate }
        
        let recentSales = marketData.soldInLast30Days
        
        switch recentSales {
        case 0...2:
            return .low
        case 3...10:
            return .moderate
        case 11...25:
            return .high
        default:
            return .veryHigh
        }
    }
    
    private func generateListingTips(identification: PrecisionIdentificationResult, marketData: MarketData?, competition: CompetitionLevel) -> [String] {
        var tips: [String] = []
        
        tips.append("Use high-quality photos showing all angles")
        tips.append("Include detailed condition description")
        
        if competition == .high || competition == .veryHigh {
            tips.append("Price competitively due to high competition")
            tips.append("Consider offering fast shipping")
        }
        
        if identification.brand.lowercased().contains("nike") || identification.brand.lowercased().contains("jordan") {
            tips.append("Verify authenticity and mention it in listing")
            tips.append("Include original box if available")
        }
        
        if let marketData = marketData, marketData.averageDaysToSell ?? 0 > 30 {
            tips.append("Consider auction format for better visibility")
        }
        
        return tips
    }
    
    private func generateDescription(identification: PrecisionIdentificationResult) -> String {
        var description = "Authentic \(identification.brand) \(identification.productName)"
        
        if !identification.model.isEmpty {
            description += " - \(identification.model)"
        }
        
        if let size = identification.size, !size.isEmpty {
            description += " in size \(size)"
        }
        
        if let color = identification.color, !color.isEmpty {
            description += " in \(color)"
        }
        
        description += ".\n\nCondition: \(identification.condition.rawValue)"
        description += "\n\nPlease see photos for exact condition details. Fast shipping guaranteed!"
        
        return description
    }
    
    private func generateTitle(identification: PrecisionIdentificationResult) -> String {
        var title = identification.brand
        
        if !identification.productName.isEmpty {
            title += " \(identification.productName)"
        }
        
        if !identification.model.isEmpty {
            title += " \(identification.model)"
        }
        
        if let size = identification.size, !size.isEmpty {
            title += " Size \(size)"
        }
        
        title += " \(identification.condition.rawValue)"
        
        // eBay title limit is 80 characters
        if title.count > 77 {
            title = String(title.prefix(77)) + "..."
        }
        
        return title
    }
    
    private func generateKeywords(identification: PrecisionIdentificationResult) -> [String] {
        var keywords: [String] = []
        
        keywords.append(identification.brand.lowercased())
        keywords.append(identification.productName.lowercased())
        
        if !identification.model.isEmpty {
            keywords.append(identification.model.lowercased())
        }
        
        if let size = identification.size, !size.isEmpty {
            keywords.append("size \(size)")
        }
        
        if let color = identification.color, !color.isEmpty {
            keywords.append(color.lowercased())
        }
        
        keywords.append(identification.condition.rawValue.lowercased())
        keywords.append("authentic")
        
        // Add category-specific keywords
        let category = ProductCategory.allCases.first { $0.rawValue == identification.category } ?? .other
        switch category {
        case .sneakers:
            keywords.append(contentsOf: ["shoes", "footwear", "sneakers"])
        case .electronics:
            keywords.append(contentsOf: ["tech", "gadget", "electronics"])
        case .clothing:
            keywords.append(contentsOf: ["apparel", "fashion", "clothing"])
        default:
            break
        }
        
        return Array(Set(keywords)).filter { !$0.isEmpty }
    }
    
    // MARK: - OpenAI API Request
    private func performOpenAIRequest(requestBody: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        guard !openAIAPIKey.isEmpty else {
            print("❌ OpenAI API key not configured")
            completion(nil)
            return
        }
        
        guard let url = URL(string: Configuration.openAIEndpoint) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error encoding request: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI API error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                completion(jsonResponse)
            } catch {
                print("❌ Error parsing OpenAI response: \(error)")
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - No AIService redeclaration - removed the typealias
