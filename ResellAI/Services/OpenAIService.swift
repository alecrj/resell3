//
//  OpenAIService.swift
//  ResellAI
//
//  AI-powered photo analysis and item identification
//

import Foundation
import SwiftUI

@MainActor
class OpenAIService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = Configuration.openAIEndpoint
    
    func analyzeItem(photos: [UIImage]) async throws -> ItemAnalysis {
        guard !photos.isEmpty else {
            throw ResellAIError.invalidImage
        }
        
        // Convert images to base64
        let base64Images = photos.compactMap { image in
            image.jpegData(compressionQuality: 0.8)?.base64EncodedString()
        }
        
        guard !base64Images.isEmpty else {
            throw ResellAIError.invalidImage
        }
        
        // Create the analysis prompt
        let analysisResult = try await performAnalysis(base64Images: base64Images)
        
        // Convert photos to Data for storage
        let photoData = photos.compactMap { $0.jpegData(compressionQuality: 0.8) }
        
        // Get eBay comps using the analysis results
        let ebayService = EbayService()
        let comps = try await ebayService.searchSoldComps(
            searchTerms: analysisResult.searchTerms,
            category: analysisResult.category
        )
        
        // Calculate pricing based on comps
        let pricing = calculatePricing(from: comps)
        
        return ItemAnalysis(
            title: analysisResult.title,
            brand: analysisResult.brand,
            category: analysisResult.category,
            condition: ItemCondition(rawValue: analysisResult.condition) ?? .good,
            description: analysisResult.description,
            confidence: analysisResult.confidence,
            suggestedPrice: pricing.competitive,
            quickSalePrice: pricing.quickSale,
            premiumPrice: pricing.premium,
            ebayComps: comps,
            photos: photoData
        )
    }
    
    private func performAnalysis(base64Images: [String]) async throws -> OpenAIAnalysisResponse {
        guard !apiKey.isEmpty else {
            throw ResellAIError.configurationError("OpenAI API key not set")
        }
        
        let messages = createAnalysisMessages(base64Images: base64Images)
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 1000,
            "temperature": 0.1
        ]
        
        guard let url = URL(string: endpoint) else {
            throw ResellAIError.networkError("Invalid OpenAI endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ResellAIError.networkError("OpenAI API request failed")
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw ResellAIError.analysisError("No analysis content received")
        }
        
        return try parseAnalysisResponse(content)
    }
    
    private func createAnalysisMessages(base64Images: [String]) -> [[String: Any]] {
        let systemPrompt = """
        You are an expert reseller and product analyst. Analyze the provided photos and identify the item for resale.
        
        Respond with ONLY a valid JSON object in this exact format:
        {
            "title": "Specific product title suitable for eBay listing",
            "brand": "Brand name",
            "category": "Category (Sneakers, Clothing, Electronics, Accessories, Home, Collectibles, Books, Toys, Sports, or Other)",
            "condition": "Exact condition (New with tags, New without tags, New other, Like New, Excellent, Very Good, Good, Acceptable, or For parts or not working)",
            "description": "Detailed description for eBay listing including flaws, size, color, model, etc.",
            "confidence": 0.95,
            "keyFeatures": ["feature1", "feature2", "feature3"],
            "searchTerms": ["search term 1", "search term 2", "search term 3"]
        }
        
        Be specific and accurate. The title should be eBay-ready. Include size, color, model numbers when visible.
        Search terms should be what buyers would search for on eBay to find this exact item.
        """
        
        var messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ]
        ]
        
        // Add user message with images
        var imageContent: [[String: Any]] = []
        
        for base64Image in base64Images {
            imageContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ])
        }
        
        imageContent.append([
            "type": "text",
            "text": "Analyze these photos and provide the JSON response for this resale item."
        ])
        
        messages.append([
            "role": "user",
            "content": imageContent
        ])
        
        return messages
    }
    
    private func parseAnalysisResponse(_ content: String) throws -> OpenAIAnalysisResponse {
        // Extract JSON from the response (in case there's extra text)
        let jsonStart = content.firstIndex(of: "{") ?? content.startIndex
        let jsonEnd = content.lastIndex(of: "}") ?? content.index(before: content.endIndex)
        let jsonString = String(content[jsonStart...jsonEnd])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ResellAIError.analysisError("Invalid JSON response")
        }
        
        do {
            return try JSONDecoder().decode(OpenAIAnalysisResponse.self, from: jsonData)
        } catch {
            print("JSON parsing error: \(error)")
            print("Response content: \(content)")
            throw ResellAIError.analysisError("Failed to parse analysis response")
        }
    }
    
    private func calculatePricing(from comps: [EbayComp]) -> (quickSale: Double, competitive: Double, premium: Double) {
        guard !comps.isEmpty else {
            return (quickSale: 50.0, competitive: 75.0, premium: 100.0)
        }
        
        // Sort by total price (including shipping)
        let sortedComps = comps.sorted { $0.totalPrice < $1.totalPrice }
        let prices = sortedComps.map { $0.totalPrice }
        
        // Calculate percentiles
        let medianPrice = percentile(prices, 0.5)
        let lowerQuartile = percentile(prices, 0.25)
        let upperQuartile = percentile(prices, 0.75)
        
        // Apply pricing strategies
        let competitive = medianPrice
        let quickSale = max(lowerQuartile, competitive * PricingStrategy.quickSale.multiplier)
        let premium = min(upperQuartile, competitive * PricingStrategy.premium.multiplier)
        
        return (
            quickSale: round(quickSale * 100) / 100,
            competitive: round(competitive * 100) / 100,
            premium: round(premium * 100) / 100
        )
    }
    
    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let sorted = values.sorted()
        let index = p * Double(sorted.count - 1)
        let lower = Int(index)
        let upper = min(lower + 1, sorted.count - 1)
        let weight = index - Double(lower)
        
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }
}

// MARK: - OpenAI Response Models
private struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}
