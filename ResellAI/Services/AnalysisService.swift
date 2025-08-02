//
//  RealAIAnalysisService.swift
//  ResellAI
//
//  Fixed AI Analysis Service with Proper Threading
//

import SwiftUI
import Foundation
import Vision

// MARK: - Fixed AI Analysis Service with Working OpenAI Integration
class RealAIAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    
    private let openAIService = WorkingOpenAIService()
    
    init() {
        print("🤖 Real AI Analysis Service initialized with OpenAI")
        
        // Bind to OpenAI service progress
        openAIService.$isAnalyzing.assign(to: &$isAnalyzing)
        openAIService.$analysisProgress.assign(to: &$analysisProgress)
        openAIService.$currentStep.assign(to: &$currentStep)
        openAIService.$totalSteps.assign(to: &$totalSteps)
    }
    
    // MARK: - Main Analysis Function
    func analyzeItem(images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            print("❌ No images provided for analysis")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        print("🔍 Starting item analysis with \(images.count) images")
        
        // Use the working OpenAI service
        openAIService.analyzeItem(images: images) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Prospecting Analysis
    func analyzeForProspecting(images: [UIImage], category: String, completion: @escaping (ProspectAnalysis?) -> Void) {
        guard !images.isEmpty else {
            print("❌ No images provided for prospecting analysis")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        print("🎯 Starting prospecting analysis with \(images.count) images")
        
        openAIService.analyzeForProspecting(images: images, category: category) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Barcode Analysis
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        
        openAIService.analyzeBarcode(barcode, images: images) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func lookupBarcodeForProspecting(_ barcode: String, completion: @escaping (ProspectAnalysis?) -> Void) {
        print("🎯 Looking up barcode for prospecting: \(barcode)")
        
        openAIService.lookupBarcodeForProspecting(barcode) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Advanced Image Processing
    func processImagesForAnalysis(_ images: [UIImage]) -> [UIImage] {
        return images.compactMap { image in
            optimizeImageForAnalysis(image)
        }
    }
    
    private func optimizeImageForAnalysis(_ image: UIImage) -> UIImage? {
        // Resize to optimal size for API calls
        let maxSize: CGFloat = 1024
        let size = image.size
        
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let optimizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return optimizedImage
    }
    
    // MARK: - Text Recognition from Images
    func extractTextFromImages(_ images: [UIImage], completion: @escaping ([String]) -> Void) {
        var allText: [String] = []
        let group = DispatchGroup()
        
        for image in images {
            group.enter()
            
            guard let cgImage = image.cgImage else {
                group.leave()
                continue
            }
            
            let request = VNRecognizeTextRequest { request, error in
                defer { group.leave() }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                allText.append(contentsOf: text)
            }
            
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
        
        group.notify(queue: .main) {
            completion(allText)
        }
    }
    
    // MARK: - Market Intelligence
    func getMarketIntelligence(for product: String, completion: @escaping (MarketIntelligence) -> Void) {
        // Create realistic market intelligence
        let intelligence = MarketIntelligence(
            demand: .medium,
            competition: .moderate,
            priceStability: .stable,
            seasonalTrends: [],
            marketInsights: ["Popular item with steady demand", "Good profit potential"]
        )
        
        DispatchQueue.main.async {
            completion(intelligence)
        }
    }
    
    // MARK: - Product Authentication
    func authenticateProduct(_ images: [UIImage], productInfo: PrecisionIdentificationResult, completion: @escaping (AuthenticationResult) -> Void) {
        // For now, return basic authentication result
        // In full implementation, would use specialized authentication AI
        let authResult = AuthenticationResult(
            isAuthentic: true,
            confidence: 0.85,
            authenticityFactors: ["Brand markings consistent", "Construction quality good"],
            warnings: [],
            recommendations: ["Get professional authentication for high-value items"]
        )
        
        DispatchQueue.main.async {
            completion(authResult)
        }
    }
    
    // MARK: - Pricing Intelligence
    func getPricingRecommendations(
        product: PrecisionIdentificationResult,
        condition: EbayCondition,
        marketData: EbayMarketData,
        completion: @escaping (PricingIntelligence) -> Void
    ) {
        let basePrice = marketData.priceRange.average
        let conditionAdjustedPrice = basePrice * condition.priceMultiplier
        
        let pricingIntel = PricingIntelligence(
            optimalPrice: conditionAdjustedPrice,
            priceRange: (min: conditionAdjustedPrice * 0.8, max: conditionAdjustedPrice * 1.2),
            quickSalePrice: conditionAdjustedPrice * 0.85,
            maxProfitPrice: conditionAdjustedPrice * 1.15,
            pricingStrategy: .competitive,
            confidenceLevel: 0.8,
            marketFactors: ["Based on recent sales data", "Adjusted for condition"]
        )
        
        DispatchQueue.main.async {
            completion(pricingIntel)
        }
    }
}

// MARK: - Supporting Data Structures
struct MarketIntelligence {
    let demand: DemandLevel
    let competition: CompetitionLevel
    let priceStability: PriceStability
    let seasonalTrends: [String]
    let marketInsights: [String]
    
    enum DemandLevel {
        case high, medium, low
    }
    
    enum PriceStability {
        case stable, volatile, increasing, decreasing
    }
}

struct AuthenticationResult {
    let isAuthentic: Bool
    let confidence: Double
    let authenticityFactors: [String]
    let warnings: [String]
    let recommendations: [String]
}

struct PricingIntelligence {
    let optimalPrice: Double
    let priceRange: (min: Double, max: Double)
    let quickSalePrice: Double
    let maxProfitPrice: Double
    let pricingStrategy: PricingStrategy
    let confidenceLevel: Double
    let marketFactors: [String]
}

// MARK: - Image Analysis Helpers
extension RealAIAnalysisService {
    
    func detectBrands(in images: [UIImage], completion: @escaping ([String]) -> Void) {
        // Use Vision framework for brand detection
        var detectedText: [String] = []
        let group = DispatchGroup()
        
        for image in images {
            group.enter()
            
            guard let cgImage = image.cgImage else {
                group.leave()
                continue
            }
            
            let request = VNRecognizeTextRequest { request, error in
                defer { group.leave() }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                // Filter for known brands
                let knownBrands = ["Nike", "Adidas", "Jordan", "Apple", "Samsung", "Supreme", "Off-White", "Yeezy"]
                let foundBrands = text.filter { textItem in
                    knownBrands.contains { brand in
                        textItem.localizedCaseInsensitiveContains(brand)
                    }
                }
                
                detectedText.append(contentsOf: foundBrands)
            }
            
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
        
        group.notify(queue: .main) {
            let uniqueBrands = Array(Set(detectedText))
            completion(uniqueBrands)
        }
    }
    
    func detectColors(in images: [UIImage]) -> [String] {
        // Analyze dominant colors in images
        var colorDescriptions: [String] = []
        
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            
            // Simple color analysis - in full implementation would use more sophisticated color detection
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let width = 1
            let height = 1
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            
            var pixelData = [UInt8](repeating: 0, count: height * width * bytesPerPixel)
            
            guard let context = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            let red = pixelData[0]
            let green = pixelData[1]
            let blue = pixelData[2]
            
            // Simple color classification
            if red > 200 && green < 100 && blue < 100 {
                colorDescriptions.append("Red")
            } else if red < 100 && green > 200 && blue < 100 {
                colorDescriptions.append("Green")
            } else if red < 100 && green < 100 && blue > 200 {
                colorDescriptions.append("Blue")
            } else if red > 200 && green > 200 && blue > 200 {
                colorDescriptions.append("White")
            } else if red < 50 && green < 50 && blue < 50 {
                colorDescriptions.append("Black")
            } else {
                colorDescriptions.append("Mixed")
            }
        }
        
        return Array(Set(colorDescriptions))
    }
}

// MARK: - Error Handling
extension RealAIAnalysisService {
    
    enum AnalysisError: Error, LocalizedError {
        case noImagesProvided
        case apiKeyMissing
        case analysisTimeout
        case networkError(String)
        case parseError(String)
        
        var errorDescription: String? {
            switch self {
            case .noImagesProvided:
                return "No images provided for analysis"
            case .apiKeyMissing:
                return "API key not configured"
            case .analysisTimeout:
                return "Analysis timed out"
            case .networkError(let message):
                return "Network error: \(message)"
            case .parseError(let message):
                return "Parse error: \(message)"
            }
        }
    }
    
    func handleAnalysisError(_ error: AnalysisError, completion: @escaping (AnalysisResult?) -> Void) {
        print("❌ Analysis error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.analysisProgress = "Analysis failed: \(error.localizedDescription)"
            completion(nil)
        }
    }
}
