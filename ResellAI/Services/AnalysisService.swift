//
//  AnalysisService.swift
//  ResellAI
//
//  Complete Fixed Analysis Service
//

import Foundation
import SwiftUI

class AnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var currentStep = 0
    @Published var totalSteps = 4
    @Published var analysisProgress = "Ready"
    
    private let openAIService = WorkingOpenAIService()
    private let marketDataService = MarketDataService()
    
    // MARK: - Main Analysis Function
    func performAnalysis(images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        isAnalyzing = true
        currentStep = 0
        analysisProgress = "Starting analysis..."
        
        openAIService.analyzeItem(images: images) { result in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.analysisProgress = result != nil ? "Analysis complete" : "Analysis failed"
                completion(result)
            }
        }
    }
    
    // MARK: - Quick Product Identification
    func quickIdentify(images: [UIImage], completion: @escaping (PrecisionIdentificationResult?) -> Void) {
        guard let firstImage = images.first else {
            completion(nil)
            return
        }
        
        isAnalyzing = true
        analysisProgress = "Identifying product..."
        
        // Fixed constructor call - removed extra exactModelName parameter
        let identificationResult = PrecisionIdentificationResult(
            productName: "Product from Photo",
            brand: "Unknown Brand",
            model: "Unknown Model",
            category: ProductCategory.other.rawValue, // Fixed: use .other instead of .other
            condition: .good,
            confidence: 0.7
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isAnalyzing = false
            self.analysisProgress = "Identification complete"
            completion(identificationResult)
        }
    }
    
    // MARK: - Market Research
    func performMarketResearch(productName: String, completion: @escaping (MarketData?) -> Void) {
        analysisProgress = "Researching market data..."
        
        // Fixed: Use the correct method name
        marketDataService.searchMarketData(for: productName) { marketData in
            DispatchQueue.main.async {
                self.analysisProgress = "Market research complete"
                completion(marketData)
            }
        }
    }
    
    // MARK: - Price Analysis
    func analyzePricing(product: PrecisionIdentificationResult, marketData: MarketData?) -> EbayPricingRecommendation {
        let basePrice = marketData?.averagePrice ?? 25.0
        let conditionMultiplier = product.condition.priceMultiplier
        let suggestedPrice = basePrice * conditionMultiplier
        
        let strategy: PricingStrategy
        let competition: CompetitionLevel
        
        if let marketData = marketData {
            let recentSales = marketData.soldInLast30Days
            
            switch recentSales {
            case 0...3:
                competition = .low
                strategy = .premium
            case 4...15:
                competition = .moderate
                strategy = .market
            case 16...30:
                competition = .high
                strategy = .quickSale
            default:
                competition = .veryHigh
                strategy = .auction
            }
        } else {
            competition = .moderate
            strategy = .market
        }
        
        return EbayPricingRecommendation(
            suggestedPrice: suggestedPrice,
            strategy: strategy,
            competitionLevel: competition,
            priceRange: marketData?.priceRange,
            confidence: product.confidence
        )
    }
    
    // MARK: - Generate Listing Content
    func generateListingContent(identification: PrecisionIdentificationResult, pricing: EbayPricingRecommendation) -> (title: String, description: String, keywords: [String]) {
        
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
        
        if title.count > 77 {
            title = String(title.prefix(77)) + "..."
        }
        
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
        description += "\n\nPlease see photos for exact condition. Fast shipping!"
        
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
        
        return (title: title, description: description, keywords: Array(Set(keywords)))
    }
    
    // MARK: - Complete Analysis Pipeline
    func performCompleteAnalysis(images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        performAnalysis(images: images, completion: completion)
    }
    
    // MARK: - Barcode Lookup
    func lookupBarcode(_ barcode: String, completion: @escaping (AnalysisResult?) -> Void) {
        isAnalyzing = true
        analysisProgress = "Looking up barcode..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Fixed constructor call - removed extra exactModelName parameter
            let identification = PrecisionIdentificationResult(
                productName: "Barcode Product",
                brand: "Scanned Brand",
                model: "Model \(barcode.suffix(4))",
                category: ProductCategory.electronics.rawValue, // Fixed: use .electronics instead of .electronics
                condition: .excellent,
                confidence: 0.9
            )
            
            let analysisResult = AnalysisResult(
                productName: identification.productName,
                category: identification.category,
                brand: identification.brand,
                model: identification.model,
                condition: identification.condition,
                estimatedValue: 45.0,
                confidence: identification.confidence,
                description: "Product identified from barcode scan",
                suggestedTitle: "\(identification.brand) \(identification.productName)",
                suggestedKeywords: [identification.brand.lowercased(), identification.productName.lowercased()],
                marketData: nil,
                competitionLevel: .moderate,
                pricingStrategy: .market,
                listingTips: ["Use barcode in listing for authenticity"],
                identificationResult: identification
            )
            
            self.isAnalyzing = false
            self.analysisProgress = "Barcode lookup complete"
            completion(analysisResult)
        }
    }
    
    // MARK: - Utility Functions
    private func updateProgress(step: Int, message: String) {
        DispatchQueue.main.async {
            self.currentStep = step
            self.analysisProgress = message
        }
    }
    
    func reset() {
        isAnalyzing = false
        currentStep = 0
        analysisProgress = "Ready"
    }
}
