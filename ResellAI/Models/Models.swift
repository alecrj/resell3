// MARK: - Fixed Models.swift with Data Corruption Handling
import SwiftUI
import Foundation

// MARK: - Core Models with eBay Condition System
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
    var condition: String // Now uses eBay condition standards
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
    var ebayCondition: EbayCondition? // NEW: eBay-specific condition
    var marketConfidence: Double?     // NEW: Market data confidence
    var soldListingsCount: Int?       // NEW: Number of sold items found
    var priceRange: EbayPriceRange?   // NEW: Real market price range
    var lastMarketUpdate: Date?       // NEW: When market data was last fetched
    
    // AI analysis fields
    var aiConfidence: Double?
    var competitorCount: Int?
    var demandLevel: String?
    var listingStrategy: String?
    var sourcingTips: [String]?
    
    // Product identification
    var barcode: String?
    var brand: String = ""
    var exactModel: String = ""      // NEW: Exact model (e.g., "Air Force 1 Low '07")
    var styleCode: String = ""       // NEW: Style/SKU code
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
    
    init(itemNumber: Int, name: String, category: String, purchasePrice: Double,
         suggestedPrice: Double, source: String, condition: String, title: String,
         description: String, keywords: [String], status: ItemStatus, dateAdded: Date,
         actualPrice: Double? = nil, dateListed: Date? = nil, dateSold: Date? = nil,
         imageData: Data? = nil, additionalImageData: [Data]? = nil, ebayURL: String? = nil,
         resalePotential: Int? = nil, marketNotes: String? = nil,
         aiConfidence: Double? = nil, competitorCount: Int? = nil, demandLevel: String? = nil,
         listingStrategy: String? = nil, sourcingTips: [String]? = nil,
         barcode: String? = nil, brand: String = "", exactModel: String = "",
         styleCode: String = "", size: String = "", colorway: String = "",
         releaseYear: String = "", subcategory: String = "", authenticationNotes: String = "",
         storageLocation: String = "", binNumber: String = "", isPackaged: Bool = false,
         packagedDate: Date? = nil, ebayCondition: EbayCondition? = nil,
         marketConfidence: Double? = nil, soldListingsCount: Int? = nil,
         priceRange: EbayPriceRange? = nil, lastMarketUpdate: Date? = nil) {
        
        self.itemNumber = itemNumber
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
        self.additionalImageData = additionalImageData
        self.ebayURL = ebayURL
        self.resalePotential = resalePotential
        self.marketNotes = marketNotes
        self.aiConfidence = aiConfidence
        self.competitorCount = competitorCount
        self.demandLevel = demandLevel
        self.listingStrategy = listingStrategy
        self.sourcingTips = sourcingTips
        self.barcode = barcode
        self.brand = brand
        self.exactModel = exactModel
        self.styleCode = styleCode
        self.size = size
        self.colorway = colorway
        self.releaseYear = releaseYear
        self.subcategory = subcategory
        self.authenticationNotes = authenticationNotes
        self.storageLocation = storageLocation
        self.binNumber = binNumber
        self.isPackaged = isPackaged
        self.packagedDate = packagedDate
        self.ebayCondition = ebayCondition
        self.marketConfidence = marketConfidence
        self.soldListingsCount = soldListingsCount
        self.priceRange = priceRange
        self.lastMarketUpdate = lastMarketUpdate
    }
    
    var profit: Double {
        guard let actualPrice = actualPrice else { return 0 }
        let fees = actualPrice * 0.1325
        return actualPrice - purchasePrice - fees
    }
    
    var roi: Double {
        guard purchasePrice > 0 else { return 0 }
        return (profit / purchasePrice) * 100
    }
    
    var estimatedProfit: Double {
        let fees = suggestedPrice * 0.1325
        return suggestedPrice - purchasePrice - fees
    }
    
    var estimatedROI: Double {
        guard purchasePrice > 0 else { return 0 }
        return (estimatedProfit / purchasePrice) * 100
    }
}

// MARK: - FIXED ItemStatus with Data Corruption Handling
enum ItemStatus: String, CaseIterable, Codable {
    case sourced = "Sourced"
    case analyzed = "Analyzed"
    case photographed = "Photographed"
    case toList = "To List"
    case listed = "Listed"
    case sold = "Sold"
    case returned = "Returned"
    case donated = "Donated"
    
    var color: Color {
        switch self {
        case .sourced: return .orange
        case .analyzed: return .blue
        case .photographed: return .purple
        case .toList: return .yellow
        case .listed: return .green
        case .sold: return .black
        case .returned: return .red
        case .donated: return .gray
        }
    }
    
    // MARK: - Handle corrupted data during decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let statusString = try container.decode(String.self)
        
        // Handle corrupted legacy values
        switch statusString {
        case "🧠 AI Analyzed", "AI Analyzed":
            self = .analyzed
        case "📸 Photographed":
            self = .photographed
        case "📋 To List":
            self = .toList
        case "🏪 Listed":
            self = .listed
        case "💰 Sold":
            self = .sold
        default:
            // Try to initialize normally first
            if let status = ItemStatus(rawValue: statusString) {
                self = status
            } else {
                // If we can't match it, default to sourced and log
                print("⚠️ Unknown status '\(statusString)' defaulting to 'Sourced'")
                self = .sourced
            }
        }
    }
}

// MARK: - eBay Condition Standards
enum EbayCondition: String, CaseIterable, Codable {
    case newWithTags = "New with tags"
    case newWithoutTags = "New without tags"
    case newOther = "New other"
    case likeNew = "Like New"
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case acceptable = "Acceptable"
    case forPartsNotWorking = "For parts or not working"
    
    var description: String {
        switch self {
        case .newWithTags:
            return "Brand new with original tags attached"
        case .newWithoutTags:
            return "Brand new without tags"
        case .newOther:
            return "Brand new but not in original packaging"
        case .likeNew:
            return "No signs of wear, appears unused"
        case .excellent:
            return "Minimal wear, no flaws affecting use"
        case .veryGood:
            return "Light wear with minor flaws"
        case .good:
            return "Moderate wear with noticeable flaws"
        case .acceptable:
            return "Heavy wear with significant flaws"
        case .forPartsNotWorking:
            return "Major damage or not functional"
        }
    }
    
    var color: Color {
        switch self {
        case .newWithTags, .newWithoutTags, .newOther:
            return .green
        case .likeNew, .excellent:
            return .blue
        case .veryGood, .good:
            return .orange
        case .acceptable:
            return .red
        case .forPartsNotWorking:
            return .gray
        }
    }
    
    var priceMultiplier: Double {
        switch self {
        case .newWithTags: return 1.0
        case .newWithoutTags: return 0.95
        case .newOther: return 0.90
        case .likeNew: return 0.85
        case .excellent: return 0.75
        case .veryGood: return 0.65
        case .good: return 0.50
        case .acceptable: return 0.35
        case .forPartsNotWorking: return 0.20
        }
    }
}

// MARK: - eBay Market Data Structures
struct EbayPriceRange: Codable {
    let newWithTags: Double?
    let newWithoutTags: Double?
    let likeNew: Double?
    let excellent: Double?
    let veryGood: Double?
    let good: Double?
    let acceptable: Double?
    let average: Double
    let soldCount: Int
    let dateRange: String // "Last 30 days"
    
    func priceForCondition(_ condition: EbayCondition) -> Double? {
        switch condition {
        case .newWithTags: return newWithTags
        case .newWithoutTags: return newWithoutTags
        case .newOther: return newWithoutTags
        case .likeNew: return likeNew
        case .excellent: return excellent
        case .veryGood: return veryGood
        case .good: return good
        case .acceptable: return acceptable
        case .forPartsNotWorking: return good != nil ? good! * 0.4 : nil
        }
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
}

// MARK: - Recent Sale Structure
struct RecentSale: Codable {
    let title: String
    let price: Double
    let condition: String
    let date: Date
    let shipping: Double?
    let bestOffer: Bool
    
    init(title: String, price: Double, condition: String, date: Date, shipping: Double? = nil, bestOffer: Bool = false) {
        self.title = title
        self.price = price
        self.condition = condition
        self.date = date
        self.shipping = shipping
        self.bestOffer = bestOffer
    }
}

// MARK: - Inventory Category
enum InventoryCategory: String, CaseIterable {
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
            return ["Fold neatly to prevent wrinkles", "Sort by size and brand", "Use clear bins for visibility"]
        case .jackets:
            return ["Hang on sturdy hangers", "Use garment bags for premium items", "Store in cool, dry place"]
        case .jeans:
            return ["Fold along seams", "Stack by waist size", "Keep premium brands separate"]
        case .workPants:
            return ["Hang to maintain crease", "Group by brand", "Check for stains before storing"]
        case .dresses:
            return ["Use padded hangers", "Cover with garment bags", "Store by season"]
        case .shoes:
            return ["Keep in original boxes when possible", "Stuff with paper to maintain shape", "Take photos of boxes"]
        case .accessories:
            return ["Use small compartments", "Keep pairs together", "Store jewelry safely"]
        case .electronics:
            return ["Keep in anti-static bags", "Store with all accessories", "Test before storing"]
        case .collectibles:
            return ["Use protective cases", "Control temperature and humidity", "Document condition thoroughly"]
        case .home:
            return ["Wrap fragile items carefully", "Group by category", "Store upright when possible"]
        case .books:
            return ["Store spine up", "Keep away from moisture", "Group by category or value"]
        case .toys:
            return ["Keep complete sets together", "Store in protective cases", "Check for all pieces"]
        case .sports:
            return ["Clean before storing", "Keep gear together", "Check for wear and damage"]
        case .other:
            return ["Label clearly", "Document thoroughly", "Store safely"]
        }
    }
}

// MARK: - Product Identification Result
struct PrecisionIdentificationResult {
    let exactModelName: String       // "Nike Air Force 1 Low '07"
    let brand: String               // "Nike"
    let productLine: String         // "Air Force 1"
    let styleVariant: String        // "Low '07"
    let styleCode: String           // "315122-111"
    let colorway: String            // "White/White"
    let size: String                // "10.5"
    let category: ProductCategory   // .sneakers
    let subcategory: String         // "Basketball Shoes"
    let identificationMethod: IdentificationMethod
    let confidence: Double          // 0.0-1.0
    let identificationDetails: [String] // How we identified it
    let alternativePossibilities: [String] // Other possible matches
}

enum IdentificationMethod {
    case visualAndText      // Best: Visual + text recognition
    case visualOnly         // Good: Visual features only
    case textOnly          // Okay: Text/barcode only
    case categoryBased     // Last resort: Category matching
}

enum ProductCategory: String, CaseIterable {
    case sneakers = "Sneakers"
    case clothing = "Clothing"
    case electronics = "Electronics"
    case accessories = "Accessories"
    case home = "Home & Garden"
    case collectibles = "Collectibles"
    case books = "Books"
    case toys = "Toys"
    case sports = "Sports"
    case other = "Other"
    
    // Helper function to automatically categorize based on item name
    static func fromItemName(_ name: String) -> ProductCategory {
        let lowercased = name.lowercased()
        
        if lowercased.contains("shoe") || lowercased.contains("sneaker") || lowercased.contains("jordan") ||
           lowercased.contains("nike") || lowercased.contains("adidas") || lowercased.contains("yeezy") {
            return .sneakers
        } else if lowercased.contains("shirt") || lowercased.contains("jacket") || lowercased.contains("hoodie") ||
                  lowercased.contains("dress") || lowercased.contains("pants") || lowercased.contains("jeans") {
            return .clothing
        } else if lowercased.contains("phone") || lowercased.contains("laptop") || lowercased.contains("iphone") ||
                  lowercased.contains("ipad") || lowercased.contains("watch") || lowercased.contains("electronics") {
            return .electronics
        } else if lowercased.contains("bag") || lowercased.contains("wallet") || lowercased.contains("jewelry") ||
                  lowercased.contains("sunglasses") || lowercased.contains("belt") {
            return .accessories
        } else if lowercased.contains("furniture") || lowercased.contains("decor") || lowercased.contains("kitchen") ||
                  lowercased.contains("lamp") || lowercased.contains("table") {
            return .home
        } else if lowercased.contains("collectible") || lowercased.contains("vintage") || lowercased.contains("antique") ||
                  lowercased.contains("card") || lowercased.contains("comic") {
            return .collectibles
        } else if lowercased.contains("book") || lowercased.contains("novel") || lowercased.contains("magazine") ||
                  lowercased.contains("textbook") || lowercased.contains("guide") {
            return .books
        } else if lowercased.contains("toy") || lowercased.contains("game") || lowercased.contains("puzzle") ||
                  lowercased.contains("doll") || lowercased.contains("action figure") {
            return .toys
        } else if lowercased.contains("sport") || lowercased.contains("fitness") || lowercased.contains("outdoor") ||
                  lowercased.contains("golf") || lowercased.contains("baseball") || lowercased.contains("basketball") {
            return .sports
        } else {
            return .other
        }
    }
}

// MARK: - Market Analysis Result
struct MarketAnalysisResult {
    let identifiedProduct: PrecisionIdentificationResult
    let marketData: EbayMarketData
    let conditionAssessment: EbayConditionAssessment
    let pricingRecommendation: EbayPricingRecommendation
    let listingStrategy: EbayListingStrategy
    let confidence: MarketConfidence
}

struct EbayMarketData {
    let soldListings: [EbaySoldListing]
    let priceRange: EbayPriceRange
    let marketTrend: MarketTrend
    let demandIndicators: DemandIndicators
    let competitionLevel: CompetitionLevel
    let lastUpdated: Date
}

struct EbayConditionAssessment {
    let detectedCondition: EbayCondition
    let conditionConfidence: Double
    let conditionFactors: [ConditionFactor]
    let conditionNotes: [String]
    let photographyRecommendations: [String]
}

struct ConditionFactor {
    let area: String          // "Toe box", "Heel", "Upper"
    let issue: String         // "Creasing", "Scuff", "Stain"
    let severity: Severity    // .minor, .moderate, .major
    let impactOnValue: Double // -5% to -30%
}

enum Severity {
    case minor, moderate, major, critical
}

struct EbayPricingRecommendation {
    let recommendedPrice: Double
    let priceRange: (min: Double, max: Double)
    let competitivePrice: Double
    let quickSalePrice: Double
    let maxProfitPrice: Double
    let pricingStrategy: PricingStrategy
    let priceJustification: [String]
}

enum PricingStrategy {
    case competitive    // Match market
    case premium       // Price above market (excellent condition)
    case discount      // Below market (quick sale)
    case auction       // Let market decide
}

struct EbayListingStrategy {
    let recommendedTitle: String
    let keywordOptimization: [String]
    let categoryPath: String
    let listingFormat: ListingFormat
    let photographyChecklist: [String]
    let descriptionTemplate: String
}

enum ListingFormat {
    case buyItNow, auction, bestOffer
}

// MARK: - Market Intelligence
struct MarketTrend {
    let direction: TrendDirection
    let strength: TrendStrength
    let timeframe: String
    let seasonalFactors: [String]
}

enum TrendDirection {
    case increasing, stable, decreasing
}

enum TrendStrength {
    case strong, moderate, weak
}

struct DemandIndicators {
    let watchersPerListing: Double
    let viewsPerListing: Double
    let timeToSell: TimeToSell
    let searchVolume: SearchVolume
}

enum TimeToSell {
    case immediate      // < 1 day
    case fast          // 1-7 days
    case normal        // 1-4 weeks
    case slow          // 1-3 months
    case difficult     // 3+ months
}

enum SearchVolume {
    case high, medium, low
}

enum CompetitionLevel {
    case low, moderate, high, saturated
}

struct MarketConfidence {
    let overall: Double           // 0.0-1.0
    let identification: Double    // How sure we are about the product
    let condition: Double         // How sure we are about condition
    let pricing: Double          // How sure we are about market price
    let dataQuality: DataQuality
}

enum DataQuality {
    case excellent   // 50+ recent sales
    case good       // 20-49 recent sales
    case fair       // 5-19 recent sales
    case limited    // 1-4 recent sales
    case insufficient // 0 recent sales
}

// MARK: - Analysis Result
struct AnalysisResult {
    let identificationResult: PrecisionIdentificationResult
    let marketAnalysis: MarketAnalysisResult
    let ebayCondition: EbayCondition
    let ebayPricing: EbayPricingRecommendation
    let soldListings: [EbaySoldListing]
    let confidence: MarketConfidence
    let images: [UIImage]
    
    // Computed properties for compatibility
    var itemName: String { identificationResult.exactModelName }
    var brand: String { identificationResult.brand }
    var category: String { identificationResult.category.rawValue }
    var actualCondition: String { ebayCondition.rawValue }
    var realisticPrice: Double { ebayPricing.recommendedPrice }
    var quickSalePrice: Double { ebayPricing.quickSalePrice }
    var maxProfitPrice: Double { ebayPricing.maxProfitPrice }
    var competitorCount: Int { soldListings.count }
    var demandLevel: String {
        switch marketAnalysis.marketData.demandIndicators.searchVolume {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    var ebayTitle: String { marketAnalysis.listingStrategy.recommendedTitle }
    var description: String { marketAnalysis.listingStrategy.descriptionTemplate }
    var keywords: [String] { marketAnalysis.listingStrategy.keywordOptimization }
    var recentSoldPrices: [Double] { soldListings.map { $0.price } }
    var averagePrice: Double { marketAnalysis.marketData.priceRange.average }
    var marketTrend: String {
        switch marketAnalysis.marketData.marketTrend.direction {
        case .increasing: return "Increasing"
        case .stable: return "Stable"
        case .decreasing: return "Decreasing"
        }
    }
    var resalePotential: Int {
        switch confidence.overall {
        case 0.9...1.0: return 10
        case 0.8...0.89: return 8
        case 0.7...0.79: return 7
        case 0.6...0.69: return 6
        case 0.5...0.59: return 5
        case 0.4...0.49: return 4
        default: return 3
        }
    }
    
    // For fees calculation
    var feesBreakdown: FeesBreakdown {
        let price = realisticPrice
        return FeesBreakdown(
            ebayFee: price * 0.1325,
            paypalFee: price * 0.0349 + 0.49,
            shippingCost: 12.50,
            listingFees: 0.35,
            totalFees: price * 0.1674 + 12.85
        )
    }
    
    var profitMargins: ProfitMargins {
        let fees = feesBreakdown
        return ProfitMargins(
            quickSaleNet: quickSalePrice - fees.totalFees,
            realisticNet: realisticPrice - fees.totalFees,
            maxProfitNet: maxProfitPrice - fees.totalFees
        )
    }
}

// MARK: - Fee structures
struct FeesBreakdown {
    let ebayFee: Double
    let paypalFee: Double
    let shippingCost: Double
    let listingFees: Double
    let totalFees: Double
}

struct ProfitMargins {
    let quickSaleNet: Double
    let realisticNet: Double
    let maxProfitNet: Double
}

struct PriceRange {
    var low: Double
    var high: Double
    var average: Double
    
    init(low: Double = 0, high: Double = 0, average: Double = 0) {
        self.low = low
        self.high = high
        self.average = average
    }
}

// MARK: - Prospecting Analysis
struct ProspectAnalysis {
    let identificationResult: PrecisionIdentificationResult
    let marketAnalysis: MarketAnalysisResult
    let maxBuyPrice: Double
    let targetBuyPrice: Double
    let breakEvenPrice: Double
    let recommendation: ProspectDecision
    let confidence: MarketConfidence
    let images: [UIImage]
    
    // Computed properties for compatibility
    var itemName: String { identificationResult.exactModelName }
    var brand: String { identificationResult.brand }
    var condition: String { marketAnalysis.conditionAssessment.detectedCondition.rawValue }
    var estimatedSellPrice: Double { marketAnalysis.pricingRecommendation.recommendedPrice }
    var potentialProfit: Double { estimatedSellPrice - maxBuyPrice - (estimatedSellPrice * 0.15) }
    var expectedROI: Double { maxBuyPrice > 0 ? (potentialProfit / maxBuyPrice) * 100 : 0 }
    var resalePotential: Int {
        switch confidence.overall {
        case 0.9...1.0: return 10
        case 0.8...0.89: return 8
        case 0.7...0.79: return 7
        case 0.6...0.69: return 6
        case 0.5...0.59: return 5
        case 0.4...0.49: return 4
        default: return 3
        }
    }
    
    var recentSales: [RecentSale] {
        return marketAnalysis.marketData.soldListings.map { listing in
            RecentSale(
                title: listing.title,
                price: listing.price,
                condition: listing.condition,
                date: listing.soldDate,
                shipping: listing.shippingCost,
                bestOffer: listing.bestOffer
            )
        }
    }
    
    var demandLevel: String {
        switch marketAnalysis.marketData.demandIndicators.searchVolume {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var riskLevel: String {
        switch expectedROI {
        case 100...: return "Low"
        case 50..<100: return "Medium"
        default: return "High"
        }
    }
    
    var sellTimeEstimate: String {
        switch marketAnalysis.marketData.demandIndicators.timeToSell {
        case .immediate: return "< 1 day"
        case .fast: return "1-7 days"
        case .normal: return "1-4 weeks"
        case .slow: return "1-3 months"
        case .difficult: return "3+ months"
        }
    }
}

enum ProspectDecision: String {
    case strongBuy = "Strong Buy"
    case buy = "Buy"
    case maybeWorthIt = "Maybe Worth It"
    case investigate = "Investigate Further"
    case pass = "Pass"
    
    var emoji: String {
        switch self {
        case .strongBuy: return "🔥"
        case .buy: return "✅"
        case .maybeWorthIt: return "🤔"
        case .investigate: return "🔍"
        case .pass: return "❌"
        }
    }
    
    var title: String {
        return rawValue
    }
    
    var color: Color {
        switch self {
        case .strongBuy: return .green
        case .buy: return .blue
        case .maybeWorthIt: return .orange
        case .investigate: return .yellow
        case .pass: return .red
        }
    }
}

// MARK: - Inventory Statistics
struct InventoryStatistics {
    let totalItems: Int
    let listedItems: Int
    let soldItems: Int
    let totalInvestment: Double
    let totalProfit: Double
    let averageROI: Double
    let estimatedValue: Double
    
    var successRate: Double {
        guard totalItems > 0 else { return 0 }
        return (Double(soldItems) / Double(totalItems)) * 100
    }
    
    var averageItemValue: Double {
        guard totalItems > 0 else { return 0 }
        return estimatedValue / Double(totalItems)
    }
    
    var averageProfit: Double {
        guard soldItems > 0 else { return 0 }
        return totalProfit / Double(soldItems)
    }
}

// MARK: - Product Data Structure
struct RealProductData {
    let name: String
    let brand: String
    let model: String
    let category: String
    let size: String
    let colorway: String
    let retailPrice: Double
    let releaseYear: String
    let confidence: Double
}
