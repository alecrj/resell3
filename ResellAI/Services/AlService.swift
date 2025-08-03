//
//  AIService.swift
//  ResellAI
//
//  AI Service for Business Operations - No Duplicates
//

import SwiftUI
import Foundation

// MARK: - AI Service for Business Operations
class AIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    
    private let realService = RealAIAnalysisService()
    
    init() {
        print("🤖 AI Service initialized")
        
        // Bind published properties from real service to avoid threading issues
        realService.$isAnalyzing.receive(on: DispatchQueue.main).assign(to: &$isAnalyzing)
        realService.$analysisProgress.receive(on: DispatchQueue.main).assign(to: &$analysisProgress)
        realService.$currentStep.receive(on: DispatchQueue.main).assign(to: &$currentStep)
        realService.$totalSteps.receive(on: DispatchQueue.main).assign(to: &$totalSteps)
    }
    
    // MARK: - Main Analysis Function
    func analyzeItem(_ images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            print("❌ No images provided for analysis")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        print("🔍 Starting analysis with \(images.count) images")
        
        // Use real service for analysis
        realService.analyzeItem(images: images) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Barcode Analysis
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        
        realService.analyzeBarcode(barcode, images: images) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Additional Analysis Features
    func getProductAuthentication(images: [UIImage], productInfo: PrecisionIdentificationResult, completion: @escaping (AuthenticationResult) -> Void) {
        realService.authenticateProduct(images, productInfo: productInfo) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func getMarketIntelligence(for product: String, completion: @escaping (MarketIntelligence) -> Void) {
        realService.getMarketIntelligence(for: product) { intelligence in
            DispatchQueue.main.async {
                completion(intelligence)
            }
        }
    }
    
    func extractTextFromImages(_ images: [UIImage], completion: @escaping ([String]) -> Void) {
        realService.extractTextFromImages(images) { textArray in
            DispatchQueue.main.async {
                completion(textArray)
            }
        }
    }
    
    func detectBrands(in images: [UIImage], completion: @escaping ([String]) -> Void) {
        realService.detectBrands(in: images) { brands in
            DispatchQueue.main.async {
                completion(brands)
            }
        }
    }
    
    // MARK: - Status Methods
    var isConfigured: Bool {
        return !Configuration.openAIKey.isEmpty
    }
    
    var configurationStatus: String {
        if isConfigured {
            return "OpenAI configured and ready"
        } else {
            return "OpenAI API key missing"
        }
    }
    
    // MARK: - Utility Methods
    func cancelAnalysis() {
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.analysisProgress = "Analysis cancelled"
            self.currentStep = 0
        }
    }
    
    func resetProgress() {
        DispatchQueue.main.async {
            self.currentStep = 0
            self.analysisProgress = "Ready"
            self.isAnalyzing = false
        }
    }
}

// MARK: - eBay Listing Service
class EbayListingService: ObservableObject {
    @Published var isListing = false
    @Published var listingProgress = "Ready to list"
    @Published var listingResults: [EbayListingResult] = []
    @Published var autoListingQueue: [InventoryItem] = []
    
    private let ebayAPIService = EbayAPIService()
    
    init() {
        print("🏪 eBay Listing Service initialized")
    }
    
    // MARK: - Single Item Listing
    func listItemToEbay(
        item: InventoryItem,
        analysis: AnalysisResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        print("🏪 Creating eBay listing for: \(item.name)")
        
        isListing = true
        listingProgress = "Creating eBay listing..."
        
        // Ensure eBay is authenticated
        if !ebayAPIService.isAuthenticated {
            ebayAPIService.authenticate { [weak self] success in
                if success {
                    self?.createListing(item: item, analysis: analysis, completion: completion)
                } else {
                    let result = EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "eBay authentication failed"
                    )
                    completion(result)
                    self?.isListing = false
                }
            }
        } else {
            createListing(item: item, analysis: analysis, completion: completion)
        }
    }
    
    private func createListing(
        item: InventoryItem,
        analysis: AnalysisResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        listingProgress = "Creating listing..."
        
        ebayAPIService.createListing(item: item, analysis: analysis) { [weak self] result in
            DispatchQueue.main.async {
                self?.isListing = false
                self?.listingProgress = result.success ? "✅ Listed successfully!" : "❌ Listing failed"
                
                // Store result
                self?.listingResults.append(result)
                
                completion(result)
            }
        }
    }
    
    // MARK: - Listing Templates
    func generateOptimizedTitle(for analysis: AnalysisResult) -> String {
        let brand = analysis.brand.isEmpty ? "" : "\(analysis.brand) "
        let model = analysis.itemName
        let size = analysis.identificationResult.size.isEmpty ? "" : " Size \(analysis.identificationResult.size)"
        let condition = " - \(analysis.actualCondition)"
        
        let title = "\(brand)\(model)\(size)\(condition)"
        
        // eBay title limit is 80 characters
        return String(title.prefix(80))
    }
    
    func generateOptimizedDescription(for item: InventoryItem, analysis: AnalysisResult) -> String {
        return """
        <div style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0;">
                <h1 style="margin: 0; font-size: 28px;">\(analysis.itemName)</h1>
                <p style="margin: 10px 0 0 0; font-size: 18px; opacity: 0.9;">AI-Verified & Analyzed</p>
            </div>
            
            <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px;">
                    <div>
                        <h3 style="color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px;">Product Details</h3>
                        <ul style="list-style: none; padding: 0;">
                            <li style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Brand:</strong> \(analysis.brand)</li>
                            <li style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Model:</strong> \(analysis.itemName)</li>
                            <li style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Size:</strong> \(item.size)</li>
                            <li style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Color:</strong> \(item.colorway)</li>
                            <li style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Style Code:</strong> \(analysis.identificationResult.styleCode)</li>
                        </ul>
                    </div>
                    
                    <div>
                        <h3 style="color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px;">Condition & Analysis</h3>
                        <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                            <h4 style="color: #28a745; margin: 0 0 10px 0;">Condition: \(analysis.actualCondition)</h4>
                            <p style="margin: 0; color: #666;">\(analysis.ebayCondition.description)</p>
                        </div>
                        <div style="background: #e3f2fd; padding: 15px; border-radius: 8px;">
                            <h4 style="color: #1976d2; margin: 0 0 10px 0;">AI Analysis</h4>
                            <p style="margin: 0; color: #666;">Verified with \(String(format: "%.0f", analysis.confidence.overall * 100))% confidence.</p>
                        </div>
                    </div>
                </div>
                
                <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                    <h3 style="color: #333; margin-top: 0;">Market Analysis</h3>
                    <p>Based on analysis of <strong>\(analysis.soldListings.count) recent sales</strong>, this item is priced competitively.</p>
                </div>
                
                <div style="border: 2px solid #28a745; border-radius: 8px; padding: 20px; background: #f8fff8;">
                    <h3 style="color: #28a745; margin-top: 0;">Why Buy From Us?</h3>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                        <div>
                            <p style="margin: 5px 0;"><strong>✅ AI-Verified Authentic</strong></p>
                            <p style="margin: 5px 0;"><strong>✅ Professional Photos</strong></p>
                            <p style="margin: 5px 0;"><strong>✅ Fast & Secure Shipping</strong></p>
                        </div>
                        <div>
                            <p style="margin: 5px 0;"><strong>✅ 30-Day Returns</strong></p>
                            <p style="margin: 5px 0;"><strong>✅ Excellent Customer Service</strong></p>
                            <p style="margin: 5px 0;"><strong>✅ 100% Satisfaction Guarantee</strong></p>
                        </div>
                    </div>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                    <p style="color: #666; margin: 0;">Questions? Message us anytime - we respond quickly!</p>
                </div>
            </div>
        </div>
        
        <div style="margin-top: 20px; padding: 15px; background: #263238; color: white; text-align: center; border-radius: 8px;">
            <p style="margin: 0;"><strong>Keywords:</strong> \(analysis.keywords.joined(separator: " • "))</p>
        </div>
        """
    }
    
    func generateItemSpecifics(for item: InventoryItem, analysis: AnalysisResult) -> [String: String] {
        var specifics: [String: String] = [:]
        
        if !analysis.brand.isEmpty {
            specifics["Brand"] = analysis.brand
        }
        
        if !item.size.isEmpty {
            specifics["Size"] = item.size
        }
        
        if !item.colorway.isEmpty {
            specifics["Color"] = item.colorway
        }
        
        if !analysis.identificationResult.styleCode.isEmpty {
            specifics["Style Code"] = analysis.identificationResult.styleCode
        }
        
        if !analysis.identificationResult.productLine.isEmpty {
            specifics["Product Line"] = analysis.identificationResult.productLine
        }
        
        specifics["Condition"] = analysis.actualCondition
        specifics["Authentication"] = "AI Verified"
        
        return specifics
    }
    
    // MARK: - eBay Category Mapping
    func getEbayCategory(for analysis: AnalysisResult) -> String {
        switch analysis.identificationResult.category {
        case .sneakers:
            return "15709" // Athletic Shoes
        case .clothing:
            return "11450" // Men's Clothing (would need gender detection)
        case .electronics:
            if analysis.brand.lowercased().contains("apple") {
                return "9355" // Apple Products
            }
            return "58058" // Cell Phones & Smartphones
        case .accessories:
            return "169291" // Fashion Accessories
        case .home:
            return "11700" // Home & Garden
        case .collectibles:
            return "1" // Collectibles
        case .books:
            return "267" // Books & Magazines
        case .toys:
            return "220" // Toys & Hobbies
        case .sports:
            return "888" // Sporting Goods
        case .other:
            return "267" // Everything Else
        }
    }
    
    // MARK: - Listing Performance
    func getListingPerformance() -> EbayListingPerformance {
        let totalListings = listingResults.count
        let successfulListings = listingResults.filter { $0.success }.count
        let failedListings = totalListings - successfulListings
        
        return EbayListingPerformance(
            totalListings: totalListings,
            successfulListings: successfulListings,
            failedListings: failedListings,
            successRate: totalListings > 0 ? Double(successfulListings) / Double(totalListings) * 100 : 0
        )
    }
    
    func getRecentListings() -> [EbayListingResult] {
        return Array(listingResults.suffix(10))
    }
    
    // MARK: - Auto-Listing Queue
    func addToAutoListingQueue(_ item: InventoryItem) {
        if !autoListingQueue.contains(where: { $0.id == item.id }) {
            autoListingQueue.append(item)
            print("➕ Added \(item.name) to auto-listing queue")
        }
    }
    
    func removeFromAutoListingQueue(_ item: InventoryItem) {
        autoListingQueue.removeAll { $0.id == item.id }
        print("➖ Removed \(item.name) from auto-listing queue")
    }
    
    var autoListingQueueCount: Int {
        return autoListingQueue.count
    }
}

// MARK: - eBay Listing Performance
struct EbayListingPerformance {
    let totalListings: Int
    let successfulListings: Int
    let failedListings: Int
    let successRate: Double
}

// MARK: - Service Status Monitoring
extension AIService {
    func performHealthCheck() -> ServiceHealthStatus {
        let openAIHealthy = !Configuration.openAIKey.isEmpty
        let analysisHealthy = !isAnalyzing || analysisProgress != "Analysis failed"
        
        return ServiceHealthStatus(
            openAIConfigured: openAIHealthy,
            analysisWorking: analysisHealthy,
            overallHealthy: openAIHealthy && analysisHealthy,
            lastUpdated: Date()
        )
    }
}

extension EbayListingService {
    func performHealthCheck() -> EbayServiceHealthStatus {
        let ebayConfigured = !Configuration.ebayAPIKey.isEmpty
        let listingWorking = !isListing || listingProgress != "Listing failed"
        
        return EbayServiceHealthStatus(
            ebayConfigured: ebayConfigured,
            listingWorking: listingWorking,
            overallHealthy: ebayConfigured && listingWorking,
            lastUpdated: Date()
        )
    }
}

// MARK: - Health Status Data Structures
struct ServiceHealthStatus {
    let openAIConfigured: Bool
    let analysisWorking: Bool
    let overallHealthy: Bool
    let lastUpdated: Date
}

struct EbayServiceHealthStatus {
    let ebayConfigured: Bool
    let listingWorking: Bool
    let overallHealthy: Bool
    let lastUpdated: Date
}
