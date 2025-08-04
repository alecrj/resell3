//
//  Models.swift
//  ResellAI
//
//  Complete Data Models with All Missing Types Fixed
//

import Foundation
import SwiftUI

// MARK: - Analysis Result (Fixed Structure)
struct AnalysisResult: Codable {
    let productName: String
    let category: String
    let brand: String
    let model: String
    let size: String
    let color: String
    let condition: EbayCondition
    let estimatedValue: Double
    let suggestedPrice: Double
    let confidence: Double
    let description: String
    let suggestedTitle: String
    let suggestedKeywords: [String]
    let marketData: MarketData?
    let competitionLevel: CompetitionLevel
    let pricingStrategy: PricingStrategy
    let listingTips: [String]
    let timestamp: Date
    let identificationResult: PrecisionIdentificationResult?
    
    init(productName: String, category: String, brand: String, model: String = "",
         size: String = "", color: String = "", condition: EbayCondition,
         estimatedValue: Double, confidence: Double, description: String,
         suggestedTitle: String, suggestedKeywords: [String], marketData: MarketData?,
         competitionLevel: CompetitionLevel, pricingStrategy: PricingStrategy,
         listingTips: [String], identificationResult: PrecisionIdentificationResult? = nil) {
        self.productName = productName
        self.category = category
        self.brand = brand
        self.model = model
        self.size = size
        self.color = color
        self.condition = condition
        self.estimatedValue = estimatedValue
        self.suggestedPrice = estimatedValue
        self.confidence = confidence
        self.description = description
        self.suggestedTitle = suggestedTitle
        self.suggestedKeywords = suggestedKeywords
        self.marketData = marketData
        self.competitionLevel = competitionLevel
        self.pricingStrategy = pricingStrategy
        self.listingTips = listingTips
        self.timestamp = Date()
        self.identificationResult = identificationResult
    }
}

// MARK: - Precision Identification Result (Fixed)
struct PrecisionIdentificationResult: Codable {
    let productName: String
    let brand: String
    let model: String
    let exactModelName: String
    let category: String
    let condition: EbayCondition
    let confidence: Double
    let size: String?
    let color: String?
    let year: String?
    let styleCode: String?
    let authenticity: AuthenticationResult
    
    init(productName: String, brand: String, model: String = "", exactModelName: String = "",
         category: String, condition: EbayCondition, confidence: Double,
         size: String? = nil, color: String? = nil, year: String? = nil, styleCode: String? = nil) {
        self.productName = productName
        self.brand = brand
        self.model = model
        self.exactModelName = exactModelName.isEmpty ? model : exactModelName
        self.category = category
        self.condition = condition
        self.confidence = confidence
        self.size = size
        self.color = color
        self.year = year
        self.styleCode = styleCode
        self.authenticity = AuthenticationResult(isAuthentic: true, confidence: confidence, notes: "")
    }
}

// MARK: - Inventory Item (Complete Fixed)
struct InventoryItem: Identifiable, Codable {
    let id = UUID()
    var itemNumber: Int
    var inventoryCode: String
    var name: String
    var category: String
    var purchasePrice: Double
    var suggestedPrice: Double
    var actualPrice: Double?
    var source: String
    var condition: String
    var title: String
    var description: String
    var keywords: [String]
    var status: ItemStatus
    var dateAdded: Date
    var dateListed: Date?
    var dateSold: Date?
    var imageData: Data?
    var additionalImageData: [Data]?
    var ebayURL: String?
    var resalePotential: String?
    var marketNotes: String?
    var marketConfidence: Double?
    var soldListingsCount: Int?
    var lastMarketUpdate: Date?
    var aiConfidence: Double?
    var competitorCount: Int?
    var demandLevel: String?
    var listingStrategy: String?
    var sourcingTips: [String]?
    var barcode: String?
    var brand: String = ""
    var exactModel: String = ""
    var styleCode: String = ""
    var size: String = ""
    var colorway: String = ""
    var releaseYear: String = ""
    var subcategory: String = ""
    var authenticationNotes: String = ""
    var storageLocation: String = ""
    var binNumber: String = ""
    var isPackaged: Bool = false
    var packagedDate: Date?
    var ebayCondition: EbayCondition?
    var priceRange: EbayPriceRange?
    
    // Simplified constructor from analysis result
    init(from analysis: AnalysisResult, notes: String = "") {
        self.itemNumber = 0  // Will be set by InventoryManager
        self.inventoryCode = ""  // Will be generated
        self.name = analysis.productName
        self.category = analysis.category
        self.purchasePrice = 0.0  // Must be set manually
        self.suggestedPrice = analysis.suggestedPrice
        self.source = "AI Analysis"
        self.condition = analysis.condition.rawValue
        self.title = analysis.suggestedTitle
        self.description = analysis.description
        self.keywords = analysis.suggestedKeywords
        self.status = .analyzed
        self.dateAdded = Date()
        self.brand = analysis.brand
        self.exactModel = analysis.model
        self.size = analysis.size
        self.colorway = analysis.color
        self.ebayCondition = analysis.condition
        self.aiConfidence = analysis.confidence
        self.marketNotes = notes
    }
    
    // Full constructor for manual creation
    init(itemNumber: Int, name: String, category: String, purchasePrice: Double,
         suggestedPrice: Double, source: String, condition: String, title: String,
         description: String, keywords: [String], status: ItemStatus = .analyzed,
         dateAdded: Date = Date(), actualPrice: Double? = nil, dateListed: Date? = nil,
         dateSold: Date? = nil, imageData: Data? = nil, ebayURL: String? = nil,
         brand: String = "", exactModel: String = "", size: String = "",
         colorway: String = "", storageLocation: String = "") {
        self.itemNumber = itemNumber
        self.inventoryCode = ""
        self.name = name
        self.category = category
        self.purchasePrice = purchasePrice
        self.suggestedPrice = suggestedPrice
        self.actualPrice = actualPrice
        self.source = source
        self.condition = condition
        self.title = title
        self.description = description
        self.keywords = keywords
        self.status = status
        self.dateAdded = dateAdded
        self.dateListed = dateListed
        self.dateSold = dateSold
        self.imageData = imageData
        self.ebayURL = ebayURL
        self.brand = brand
        self.exactModel = exactModel
        self.size = size
        self.colorway = colorway
        self.storageLocation = storageLocation
    }
    
    // Computed properties
    var profit: Double {
        guard let actualPrice = actualPrice else { return 0 }
        return actualPrice - purchasePrice - (actualPrice * 0.1325) - 8.50
    }
    
    var roi: Double {
        guard purchasePrice > 0, let actualPrice = actualPrice else { return 0 }
        return ((actualPrice - purchasePrice) / purchasePrice) * 100
    }
    
    var estimatedROI: Double {
        guard purchasePrice > 0 else { return 0 }
        return ((suggestedPrice - purchasePrice) / purchasePrice) * 100
    }
}

// MARK: - Inventory Category (Complete)
enum InventoryCategory: String, CaseIterable, Codable {
    case tshirts = "T-Shirts & Tops"
    case jackets = "Jackets & Outerwear"
    case jeans = "Jeans & Denim"
    case workPants = "Work Pants"
    case dresses = "Dresses & Skirts"
    case shoes = "Shoes & Footwear"
    case accessories = "Accessories"
    case electronics = "Electronics"
    case collectibles = "Collectibles"
    case home = "Home & Garden"
    case books = "Books & Media"
    case toys = "Toys & Games"
    case sports = "Sports & Outdoors"
    case other = "Other Items"
    
    var inventoryLetter: String {
        switch self {
        case .tshirts: return "A"
        case .jackets: return "B"
        case .jeans: return "C"
        case .workPants: return "D"
        case .dresses: return "E"
        case .shoes: return "F"
        case .accessories: return "G"
        case .electronics: return "H"
        case .collectibles: return "I"
        case .home: return "J"
        case .books: return "K"
        case .toys: return "L"
        case .sports: return "M"
        case .other: return "Z"
        }
    }
    
    var storageTips: [String] {
        switch self {
        case .tshirts:
            return ["Fold flat to prevent wrinkles", "Sort by size and color", "Use clear bins for visibility"]
        case .jackets:
            return ["Hang heavy coats", "Use garment bags for delicate items", "Cedar blocks for moths"]
        case .jeans:
            return ["Fold along seams", "Stack by wash and size", "Keep tags visible"]
        case .workPants:
            return ["Press before storage", "Separate by fabric type", "Use shelf dividers"]
        case .dresses:
            return ["Hang long dresses", "Use padded hangers", "Cover with garment bags"]
        case .shoes:
            return ["Clean before storage", "Use original boxes when possible", "Stuff with paper"]
        case .accessories:
            return ["Small containers for jewelry", "Wrap delicate items", "Label clearly"]
        case .electronics:
            return ["Original packaging preferred", "Anti-static bags", "Test before storage"]
        case .collectibles:
            return ["Climate controlled area", "Protective cases", "Document condition"]
        case .home:
            return ["Wrap fragile items", "Use bubble wrap", "Label boxes clearly"]
        case .books:
            return ["Store upright", "Avoid direct sunlight", "Check for damage"]
        case .toys:
            return ["Clean thoroughly", "Check for missing parts", "Original boxes add value"]
        case .sports:
            return ["Clean equipment", "Check for wear", "Store in dry area"]
        case .other:
            return ["Assess individually", "Use appropriate protection", "Document thoroughly"]
        }
    }
    
    var ebayCategory: String {
        return Configuration.ebayCategoryMappings[self.rawValue] ?? "267"
    }
}

// MARK: - Product Category Enum
enum ProductCategory: String, CaseIterable, Codable {
    case sneakers = "Sneakers"
    case electronics = "Electronics"
    case clothing = "Clothing"
    case accessories = "Accessories"
    case collectibles = "Collectibles"
    case home = "Home"
    case sports = "Sports"
    case toys = "Toys"
    case books = "Books"
    case other = "Other"
    
    var description: String {
        return self.rawValue
    }
    
    var ebayCategory: String {
        return Configuration.ebayCategoryMappings[self.rawValue] ?? "267"
    }
}

// MARK: - eBay Condition Enum
enum EbayCondition: String, CaseIterable, Codable {
    case newWithTags = "New with tags"
    case newWithoutTags = "New without tags"
    case newOther = "New other"
    case likeNew = "Like New"
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case acceptable = "Acceptable"
    case forParts = "For parts or not working"
    
    var description: String {
        return self.rawValue
    }
    
    var priceMultiplier: Double {
        switch self {
        case .newWithTags: return 1.0
        case .newWithoutTags: return 0.95
        case .newOther: return 0.9
        case .likeNew: return 0.85
        case .excellent: return 0.8
        case .veryGood: return 0.7
        case .good: return 0.6
        case .acceptable: return 0.45
        case .forParts: return 0.3
        }
    }
    
    var ebayConditionId: String {
        return Configuration.ebayConditionMappings[self.rawValue] ?? "3000"
    }
}

// MARK: - Competition Level Enum
enum CompetitionLevel: String, CaseIterable, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
    
    var description: String {
        switch self {
        case .low: return "Low competition - great opportunity"
        case .moderate: return "Moderate competition - good potential"
        case .high: return "High competition - price competitively"
        case .veryHigh: return "Very high competition - consider other items"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

// MARK: - Pricing Strategy Enum
enum PricingStrategy: String, CaseIterable, Codable {
    case quickSale = "Quick Sale"
    case market = "Market Price"
    case premium = "Premium Price"
    case auction = "Auction Style"
    case bestOffer = "Best Offer"
    
    var description: String {
        switch self {
        case .quickSale: return "Price for fast sale (7-14 days)"
        case .market: return "Price at market average"
        case .premium: return "Price above market for quality items"
        case .auction: return "Start low, let bidding drive price"
        case .bestOffer: return "Accept best offers on fixed price"
        }
    }
    
    var priceMultiplier: Double {
        switch self {
        case .quickSale: return 0.85
        case .market: return 1.0
        case .premium: return 1.15
        case .auction: return 0.75
        case .bestOffer: return 1.05
        }
    }
}

// MARK: - Item Status Enum
enum ItemStatus: String, CaseIterable, Codable {
    case sourced = "Sourced"
    case photographed = "Photographed"
    case needsAnalysis = "Needs Analysis"
    case analyzed = "Analyzed"
    case readyToList = "Ready to List"
    case toList = "To List"
    case listed = "Listed"
    case sold = "Sold"
    case returned = "Returned"
    case donated = "Donated"
    case archived = "Archived"
    
    var color: Color {
        switch self {
        case .sourced: return .gray
        case .photographed: return .blue
        case .needsAnalysis: return .gray
        case .analyzed: return .blue
        case .readyToList: return .orange
        case .toList: return .orange
        case .listed: return .yellow
        case .sold: return .green
        case .returned: return .red
        case .donated: return .purple
        case .archived: return .secondary
        }
    }
}

// MARK: - Supporting Data Structures
struct EbayPriceRange: Codable {
    let lowest: Double
    let highest: Double
    let average: Double
    let median: Double
    let sampleSize: Int
    
    var range: String {
        return String(format: "$%.2f - $%.2f", lowest, highest)
    }
    
    var averageFormatted: String {
        return String(format: "$%.2f", average)
    }
}

struct MarketData: Codable {
    let averagePrice: Double
    let priceRange: EbayPriceRange
    let soldListings: [EbaySoldListing]
    let totalSold: Int
    let averageDaysToSell: Double?
    let seasonalTrends: [String]?
    let competitorAnalysis: String?
    let demandIndicators: [String]
    let lastUpdated: Date
    
    var formattedAveragePrice: String {
        return String(format: "$%.2f", averagePrice)
    }
    
    var soldInLast30Days: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return soldListings.filter { $0.soldDate >= thirtyDaysAgo }.count
    }
}

struct EbaySoldListing: Codable {
    let title: String
    let price: Double
    let condition: String
    let soldDate: Date
    let shippingCost: Double?
    let watchers: Int?
    let bids: Int?
    let seller: String?
    let location: String?
    let itemId: String?
    
    var totalCost: Double {
        return price + (shippingCost ?? 0)
    }
    
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
}

struct AuthenticationResult: Codable {
    let isAuthentic: Bool
    let confidence: Double
    let notes: String
    let riskFactors: [String]
    
    init(isAuthentic: Bool, confidence: Double, notes: String, riskFactors: [String] = []) {
        self.isAuthentic = isAuthentic
        self.confidence = confidence
        self.notes = notes
        self.riskFactors = riskFactors
    }
}

// MARK: - Missing Types Added
struct MarketAnalysisResult: Codable {
    let intelligence: MarketIntelligence
    let pricingRecommendation: EbayPricingRecommendation
    let listingStrategy: EbayListingStrategy
    let confidence: MarketConfidence
    
    init(intelligence: MarketIntelligence) {
        self.intelligence = intelligence
        self.pricingRecommendation = EbayPricingRecommendation(
            suggestedPrice: intelligence.averagePrice,
            strategy: .market,
            competitionLevel: intelligence.competitionLevel
        )
        self.listingStrategy = EbayListingStrategy(
            timing: "immediate",
            duration: "7_days",
            format: "fixed_price"
        )
        self.confidence = MarketConfidence(level: "high", score: 0.8)
    }
}

struct MarketIntelligence: Codable {
    let averagePrice: Double
    let priceRange: EbayPriceRange
    let salesVelocity: Double
    let competitionLevel: CompetitionLevel
    let demandIndicators: DemandIndicators
    let seasonalTrends: [MarketTrend]
    let lastUpdated: Date
    
    init(averagePrice: Double, priceRange: EbayPriceRange, salesVelocity: Double, competitionLevel: CompetitionLevel) {
        self.averagePrice = averagePrice
        self.priceRange = priceRange
        self.salesVelocity = salesVelocity
        self.competitionLevel = competitionLevel
        self.demandIndicators = DemandIndicators(level: "moderate", indicators: [])
        self.seasonalTrends = []
        self.lastUpdated = Date()
    }
}

struct DemandIndicators: Codable {
    let level: String
    let indicators: [String]
    let score: Double
    
    init(level: String, indicators: [String], score: Double = 0.5) {
        self.level = level
        self.indicators = indicators
        self.score = score
    }
}

struct MarketTrend: Codable {
    let period: String
    let trend: String
    let percentage: Double
    let description: String
}

struct EbayPricingRecommendation: Codable {
    let suggestedPrice: Double
    let strategy: PricingStrategy
    let competitionLevel: CompetitionLevel
    let priceRange: EbayPriceRange?
    let confidence: Double
    
    init(suggestedPrice: Double, strategy: PricingStrategy, competitionLevel: CompetitionLevel, priceRange: EbayPriceRange? = nil, confidence: Double = 0.8) {
        self.suggestedPrice = suggestedPrice
        self.strategy = strategy
        self.competitionLevel = competitionLevel
        self.priceRange = priceRange
        self.confidence = confidence
    }
}

struct EbayListingStrategy: Codable {
    let timing: String
    let duration: String
    let format: String
    let features: [String]
    
    init(timing: String, duration: String, format: String, features: [String] = []) {
        self.timing = timing
        self.duration = duration
        self.format = format
        self.features = features
    }
}

struct MarketConfidence: Codable {
    let level: String
    let score: Double
    let factors: [String]
    
    init(level: String, score: Double, factors: [String] = []) {
        self.level = level
        self.score = score
        self.factors = factors
    }
}

struct EbayConditionAssessment: Codable {
    let condition: EbayCondition
    let confidence: Double
    let notes: String
    let priceImpact: Double
    
    init(condition: EbayCondition, confidence: Double, notes: String = "") {
        self.condition = condition
        self.confidence = confidence
        self.notes = notes
        self.priceImpact = condition.priceMultiplier
    }
}

struct EbayServiceHealthStatus: Codable {
    let isHealthy: Bool
    let lastCheck: Date
    let services: [String: Bool]
    let errorCount: Int
    
    init() {
        self.isHealthy = true
        self.lastCheck = Date()
        self.services = ["finding": true, "trading": true, "auth": true]
        self.errorCount = 0
    }
}

// MARK: - eBay Listing Data Structures
struct EbayListingData: Codable {
    let sku: String
    let title: String
    let description: String
    let categoryId: String
    let conditionId: String
    let conditionDescription: String
    let price: Double
    let currency: String
    let quantity: Int
    let imageURLs: [String]
    let brand: String
    let size: String
    let color: String
    let packageWeightAndSize: EbayPackageDetails?
    let returnPolicy: EbayReturnPolicy
    let fulfillmentPolicy: EbayFulfillmentPolicy
    let paymentPolicy: EbayPaymentPolicy
}

struct EbayPackageDetails: Codable {
    let weight: EbayWeight
    let dimensions: EbayDimensions
}

struct EbayWeight: Codable {
    let value: Double
    let unit: String
}

struct EbayDimensions: Codable {
    let length: Double
    let width: Double
    let height: Double
    let unit: String
}

struct EbayReturnPolicy: Codable {
    let returnsAccepted: Bool
    let returnPeriod: String
    let refundMethod: String
    let returnShippingCostPayer: String
}

struct EbayFulfillmentPolicy: Codable {
    let name: String
    let shippingOptions: [EbayShippingOption]
}

struct EbayShippingOption: Codable {
    let optionType: String
    let costType: String
    let shippingServices: [EbayShippingService]
}

struct EbayShippingService: Codable {
    let shippingCarrierCode: String
    let shippingServiceCode: String
    let shippingCost: EbayAmount
    let additionalShippingCost: EbayAmount?
}

struct EbayAmount: Codable {
    let value: String
    let currency: String
}

struct EbayPaymentPolicy: Codable {
    let name: String
    let description: String
    let immediatePay: Bool
}

struct EbayListingResult: Codable {
    let success: Bool
    let listingId: String?
    let listingURL: String?
    let error: String?
}

enum ListingError: Error {
    case notAuthenticated
    case invalidData
    case uploadFailed
    case networkError
    case apiError(String)
}

// MARK: - ROI and Statistics
struct ROICalculation: Codable {
    let itemCost: Double
    let sellingPrice: Double
    let estimatedFees: Double
    let projectedProfit: Double
    let roi: Double
    
    init(itemCost: Double, sellingPrice: Double) {
        self.itemCost = itemCost
        self.sellingPrice = sellingPrice
        self.estimatedFees = sellingPrice * 0.1325 + 8.50
        self.projectedProfit = sellingPrice - itemCost - estimatedFees
        self.roi = itemCost > 0 ? (projectedProfit / itemCost) * 100 : 0
    }
}

struct InventoryStatistics: Codable {
    let totalItems: Int
    let listedItems: Int
    let soldItems: Int
    let totalInvestment: Double
    let totalProfit: Double
    let averageROI: Double
    let estimatedValue: Double
}
