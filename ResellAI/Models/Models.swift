//
//  Models.swift
//  ResellAI
//
//  Complete Business Models - Single Source of Truth
//

import Foundation
import SwiftUI

// MARK: - Core Business Models
struct InventoryItem: Identifiable, Codable {
    let id = UUID()
    var itemNumber: Int
    var inventoryCode: String = ""
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
    var resalePotential: Int?
    var marketNotes: String?
    
    // Market analysis fields
    var ebayCondition: EbayCondition?
    var marketConfidence: Double?
    var soldListingsCount: Int?
    var priceRange: EbayPriceRange?
    var lastMarketUpdate: Date?
    
    // AI analysis fields
    var aiConfidence: Double?
    var competitorCount: Int?
    var demandLevel: String?
    var listingStrategy: String?
    var sourcingTips: [String]?
    
    // Product identification
    var barcode: String?
    var brand: String = ""
    var exactModel: String = ""
    var styleCode: String = ""
    var size: String = ""
    var colorway: String = ""
    var releaseYear: String = ""
    var subcategory: String = ""
    var authenticationNotes: String = ""
    
    // Physical inventory management
    var storageLocation: String = ""
    var binNumber: String = ""
    var isPackaged: Bool = false
    var packagedDate: Date?
    
    // Custom coding keys to handle non-Codable properties
    enum CodingKeys: String, CodingKey {
        case itemNumber, inventoryCode, name, category, purchasePrice, suggestedPrice
        case actualPrice, source, condition, title, description, keywords, status
        case dateAdded, dateListed, dateSold, imageData, additionalImageData
        case ebayURL, resalePotential, marketNotes, marketConfidence
        case soldListingsCount, lastMarketUpdate, aiConfidence, competitorCount
        case demandLevel, listingStrategy, sourcingTips, barcode, brand
        case exactModel, styleCode, size, colorway, releaseYear, subcategory
        case authenticationNotes, storageLocation, binNumber, isPackaged, packagedDate
        case ebayCondition, priceRange
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
        case .auction: return 0.75  // Start low
        case .bestOffer: return 1.05  // Slightly above market
        }
    }
}

// MARK: - Item Status Enum
enum ItemStatus: String, CaseIterable, Codable {
    case needsAnalysis = "Needs Analysis"
    case analyzed = "Analyzed"
    case readyToList = "Ready to List"
    case listed = "Listed"
    case sold = "Sold"
    case returned = "Returned"
    case donated = "Donated"
    case archived = "Archived"
    
    var color: Color {
        switch self {
        case .needsAnalysis: return .gray
        case .analyzed: return .blue
        case .readyToList: return .orange
        case .listed: return .yellow
        case .sold: return .green
        case .returned: return .red
        case .donated: return .purple
        case .archived: return .secondary
        }
    }
}

// MARK: - eBay Price Range
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

// MARK: - Analysis Result
struct AnalysisResult: Codable {
    let productName: String
    let category: String
    let brand: String
    let condition: EbayCondition
    let estimatedValue: Double
    let confidence: Double
    let description: String
    let suggestedTitle: String
    let suggestedKeywords: [String]
    let marketData: MarketData?
    let competitionLevel: CompetitionLevel
    let pricingStrategy: PricingStrategy
    let listingTips: [String]
    let timestamp: Date
    
    init(productName: String, category: String, brand: String, condition: EbayCondition,
         estimatedValue: Double, confidence: Double, description: String,
         suggestedTitle: String, suggestedKeywords: [String], marketData: MarketData?,
         competitionLevel: CompetitionLevel, pricingStrategy: PricingStrategy,
         listingTips: [String]) {
        self.productName = productName
        self.category = category
        self.brand = brand
        self.condition = condition
        self.estimatedValue = estimatedValue
        self.confidence = confidence
        self.description = description
        self.suggestedTitle = suggestedTitle
        self.suggestedKeywords = suggestedKeywords
        self.marketData = marketData
        self.competitionLevel = competitionLevel
        self.pricingStrategy = pricingStrategy
        self.listingTips = listingTips
        self.timestamp = Date()
    }
}

// MARK: - Market Data
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

// MARK: - eBay Sold Listing
struct EbaySoldListing: Codable {
    let title: String
    let price: Double
    let condition: String
    let soldDate: Date
    let shippingCost: Double?
    let bestOffer: Bool
    let auction: Bool
    let watchers: Int?
    
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
    
    var totalPrice: Double {
        return price + (shippingCost ?? 0)
    }
}

// MARK: - Recent Sale
struct RecentSale: Codable {
    let title: String
    let price: Double
    let condition: String
    let date: Date
    let shipping: Double?
    let bestOffer: Bool
    
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
    
    var totalPrice: Double {
        return price + (shipping ?? 0)
    }
}

// MARK: - Inventory Category
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
    
    var ebayCategory: String {
        return Configuration.ebayCategoryMappings[self.rawValue] ?? "267"
    }
}

// MARK: - Alert Models
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: String
    let secondaryButton: String?
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    
    init(title: String, message: String, primaryButton: String = "OK",
         secondaryButton: String? = nil, primaryAction: (() -> Void)? = nil,
         secondaryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

// MARK: - Photo Models
struct PhotoItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
    
    init(image: UIImage) {
        self.image = image
        self.timestamp = Date()
    }
}

// MARK: - Settings Models
struct AppSettings: Codable {
    var defaultShippingCost: Double = 8.50
    var ebayFeeRate: Double = 0.1325
    var paypalFeeRate: Double = 0.0349
    var minimumROI: Double = 50.0
    var preferredROI: Double = 100.0
    var autoListingEnabled: Bool = false
    var notificationsEnabled: Bool = true
    var darkModeEnabled: Bool = false
    var autoAnalysisEnabled: Bool = true
    var savePhotosToLibrary: Bool = false
    
    static let shared = AppSettings()
}

// MARK: - ROI Calculation
struct ROICalculation: Codable {
    let itemCost: Double
    let sellingPrice: Double
    let ebayFees: Double
    let paypalFees: Double
    let shippingCost: Double
    let netProfit: Double
    let roiPercentage: Double
    let breakEvenPrice: Double
    
    init(itemCost: Double, sellingPrice: Double, shippingCost: Double = 8.50) {
        self.itemCost = itemCost
        self.sellingPrice = sellingPrice
        self.shippingCost = shippingCost
        
        let totalRevenue = sellingPrice + shippingCost
        self.ebayFees = totalRevenue * Configuration.defaultEbayFeeRate
        self.paypalFees = totalRevenue * Configuration.defaultPayPalFeeRate + 0.49
        
        let totalCosts = itemCost + ebayFees + paypalFees + shippingCost
        self.netProfit = totalRevenue - totalCosts
        self.roiPercentage = itemCost > 0 ? (netProfit / itemCost) * 100 : 0
        
        let feeRate = Configuration.defaultEbayFeeRate + Configuration.defaultPayPalFeeRate
        self.breakEvenPrice = (itemCost + 0.49) / (1 - feeRate) - shippingCost
    }
    
    var formattedROI: String {
        return String(format: "%.1f%%", roiPercentage)
    }
    
    var formattedNetProfit: String {
        return String(format: "$%.2f", netProfit)
    }
    
    var isGoodDeal: Bool {
        return roiPercentage >= Configuration.minimumROIThreshold
    }
    
    var isPremiumDeal: Bool {
        return roiPercentage >= Configuration.preferredROIThreshold
    }
}

// MARK: - Export Models
struct InventoryExport: Codable {
    let exportDate: Date
    let totalItems: Int
    let items: [InventoryItem]
    let summary: ExportSummary
    
    init(items: [InventoryItem]) {
        self.exportDate = Date()
        self.totalItems = items.count
        self.items = items
        self.summary = ExportSummary(items: items)
    }
}

struct ExportSummary: Codable {
    let totalValue: Double
    let averageValue: Double
    let categoryBreakdown: [String: Int]
    let statusBreakdown: [String: Int]
    let topBrands: [String: Int]
    
    init(items: [InventoryItem]) {
        self.totalValue = items.reduce(0) { $0 + $1.suggestedPrice }
        self.averageValue = items.isEmpty ? 0 : totalValue / Double(items.count)
        
        var categories: [String: Int] = [:]
        var statuses: [String: Int] = [:]
        var brands: [String: Int] = [:]
        
        for item in items {
            categories[item.category, default: 0] += 1
            statuses[item.status.rawValue, default: 0] += 1
            if !item.brand.isEmpty {
                brands[item.brand, default: 0] += 1
            }
        }
        
        self.categoryBreakdown = categories
        self.statusBreakdown = statuses
        self.topBrands = brands
    }
}

// MARK: - Missing Service Data Structures
struct PrecisionIdentificationResult: Codable {
    let productName: String
    let brand: String
    let model: String
    let category: String
    let condition: EbayCondition
    let confidence: Double
    let size: String?
    let color: String?
    let year: String?
    let styleCode: String?
    let authenticity: AuthenticationResult
    
    init(productName: String, brand: String, model: String = "", category: String, condition: EbayCondition, confidence: Double, size: String? = nil, color: String? = nil, year: String? = nil, styleCode: String? = nil) {
        self.productName = productName
        self.brand = brand
        self.model = model
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
    let level: String // "low", "moderate", "high", "very_high"
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
    let trend: String // "rising", "falling", "stable"
    let percentage: Double
    let description: String
}

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

struct EbayPricingRecommendation: Codable {
    let suggestedPrice: Double
    let priceRange: EbayPriceRange?
    let strategy: PricingStrategy
    let competitionLevel: CompetitionLevel
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
    let level: String // "low", "medium", "high"
    let score: Double // 0.0 to 1.0
    let factors: [String]
    
    init(level: String, score: Double, factors: [String] = []) {
        self.level = level
        self.score = score
        self.factors = factors
    }
}

struct EbayMarketData: Codable {
    let searchResults: [EbaySoldListing]
    let averagePrice: Double
    let priceRange: EbayPriceRange
    let totalSold: Int
    let averageDaysToSell: Double?
    let lastUpdated: Date
    
    init(searchResults: [EbaySoldListing]) {
        self.searchResults = searchResults
        let prices = searchResults.map { $0.price }
        self.averagePrice = prices.isEmpty ? 0 : prices.reduce(0, +) / Double(prices.count)
        
        let sortedPrices = prices.sorted()
        self.priceRange = EbayPriceRange(
            lowest: sortedPrices.first ?? 0,
            highest: sortedPrices.last ?? 0,
            average: averagePrice,
            median: sortedPrices.isEmpty ? 0 : sortedPrices[sortedPrices.count / 2],
            sampleSize: prices.count
        )
        self.totalSold = searchResults.count
        self.averageDaysToSell = nil
        self.lastUpdated = Date()
    }
}

struct PricingIntelligence: Codable {
    let recommendation: EbayPricingRecommendation
    let marketAnalysis: String
    let riskAssessment: String
    let profitProjection: ROICalculation
    
    init(recommendation: EbayPricingRecommendation, itemCost: Double) {
        self.recommendation = recommendation
        self.marketAnalysis = "Market analysis based on recent sales data"
        self.riskAssessment = "Low risk - good market demand"
        self.profitProjection = ROICalculation(itemCost: itemCost, sellingPrice: recommendation.suggestedPrice)
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

struct InventoryStatistics: Codable {
    let totalItems: Int
    let totalValue: Double
    let averageValue: Double
    let categoryBreakdown: [String: Int]
    let statusBreakdown: [String: Int]
    let profitProjection: Double
    
    init(items: [InventoryItem]) {
        self.totalItems = items.count
        self.totalValue = items.reduce(0) { $0 + $1.suggestedPrice }
        self.averageValue = items.isEmpty ? 0 : totalValue / Double(items.count)
        
        var categories: [String: Int] = [:]
        var statuses: [String: Int] = [:]
        
        for item in items {
            categories[item.category, default: 0] += 1
            statuses[item.status.rawValue, default: 0] += 1
        }
        
        self.categoryBreakdown = categories
        self.statusBreakdown = statuses
        self.profitProjection = totalValue * 0.6 // Rough profit estimate
    }
}

struct ProductCategory: Codable {
    let name: String
    let ebayId: String
    let level: Int
    let parentId: String?
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

// MARK: - eBay Listing Structures
struct EbayListingResult {
    let success: Bool
    let listingId: String?
    let listingURL: String?
    let error: String?
}

struct EbayListingData {
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
    let unit: String // "POUND" or "KILOGRAM"
}

struct EbayDimensions: Codable {
    let length: Double
    let width: Double
    let height: Double
    let unit: String // "INCH" or "CENTIMETER"
}

struct EbayReturnPolicy: Codable {
    let returnsAccepted: Bool
    let returnPeriod: String // e.g., "Days_30"
    let refundMethod: String // e.g., "MoneyBack"
    let returnShippingCostPayer: String // e.g., "Buyer"
}

struct EbayFulfillmentPolicy: Codable {
    let name: String
    let shippingOptions: [EbayShippingOption]
}

struct EbayShippingOption: Codable {
    let optionType: String // "DOMESTIC" or "INTERNATIONAL"
    let costType: String // "FLAT_RATE" or "CALCULATED"
    let shippingServices: [EbayShippingService]
}

struct EbayShippingService: Codable {
    let shippingCarrierCode: String // e.g., "USPS"
    let shippingServiceCode: String // e.g., "USPSGround"
    let shippingCost: EbayAmount
    let additionalShippingCost: EbayAmount?
    let freeShipping: Bool
    let buyerResponsibleForShipping: Bool
    let buyerResponsibleForPickup: Bool
}

struct EbayAmount: Codable {
    let value: String
    let currency: String
}

struct EbayPaymentPolicy: Codable {
    let name: String
    let paymentMethods: [EbayPaymentMethod]
}

struct EbayPaymentMethod: Codable {
    let paymentMethodType: String // e.g., "PAYPAL", "CREDIT_CARD"
}
