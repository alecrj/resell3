//
//  EbayTokenResponse.swift
//  ResellAI
//
//  Created by Alec on 8/3/25.
//


//
//  EbayDataStructures.swift
//  ResellAI
//
//  Complete eBay API Data Structures
//

import Foundation
import CryptoKit

// MARK: - eBay Authentication Data Structures
struct EbayTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let token_type: String
    let refresh_token: String?
    let refresh_token_expires_in: Int?
}

struct EbayUserProfile: Codable {
    let userId: String
    let username: String
    let email: String?
    let registrationDate: String?
    let registrationMarketplaceId: String?
    let status: String?
}

struct EbayListingCapabilities {
    let canList: Bool
    let maxPhotos: Int
    let supportedFormats: [String]
    let sellerLevel: String
}

// MARK: - eBay Listing Data Structures
struct InventoryItem {
    let id: String
    let name: String
    let photos: [UIImage]
    let analysisResult: AnalysisResult?
    let dateAdded: Date
    let notes: String
    
    init(name: String, photos: [UIImage], notes: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.photos = photos
        self.analysisResult = nil
        self.dateAdded = Date()
        self.notes = notes
    }
}

// MARK: - eBay Condition Mappings
enum EbayCondition: String, CaseIterable {
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

// MARK: - eBay API Response Structures
struct EbayInventoryResponse: Codable {
    let warnings: [EbayWarning]?
    let errors: [EbayError]?
}

struct EbayOfferResponse: Codable {
    let offerId: String?
    let warnings: [EbayWarning]?
    let errors: [EbayError]?
}

struct EbayPublishResponse: Codable {
    let listingId: String?
    let warnings: [EbayWarning]?
    let errors: [EbayError]?
}

struct EbayWarning: Codable {
    let category: String?
    let domain: String?
    let errorId: String?
    let message: String?
    let severity: String?
}

struct EbayError: Codable {
    let category: String?
    let domain: String?
    let errorId: String?
    let message: String?
    let severity: String?
    let parameters: [EbayErrorParameter]?
}

struct EbayErrorParameter: Codable {
    let name: String?
    let value: String?
}

// MARK: - eBay Listing Performance Tracking
struct EbayListingPerformance {
    let totalListings: Int
    let successfulListings: Int
    let failedListings: Int
    let successRate: Double
    let lastUpdated: Date
    
    var performance: String {
        return String(format: "%.1f%% success rate (%d/%d)", successRate * 100, successfulListings, totalListings)
    }
}

// MARK: - Market Data Structures
struct MarketPriceRange {
    let min: Double
    let max: Double
    let average: Double
    
    var spread: Double {
        return max - min
    }
    
    var midpoint: Double {
        return (min + max) / 2
    }
}

enum DemandLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var multiplier: Double {
        switch self {
        case .high: return 1.2
        case .medium: return 1.0
        case .low: return 0.8
        }
    }
}

enum CompetitionLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var priceAdjustment: Double {
        switch self {
        case .high: return 0.9  // Lower prices due to competition
        case .medium: return 1.0
        case .low: return 1.1   // Can charge premium
        }
    }
}

// MARK: - Pricing Strategy
enum PricingStrategy: String, CaseIterable {
    case aggressive = "Aggressive"
    case competitive = "Competitive"
    case premium = "Premium"
    case quickSale = "Quick Sale"
    
    var description: String {
        switch self {
        case .aggressive:
            return "Price below market for quick sale"
        case .competitive:
            return "Price at market average"
        case .premium:
            return "Price above market for maximum profit"
        case .quickSale:
            return "Price significantly below market"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .aggressive: return 0.85
        case .competitive: return 1.0
        case .premium: return 1.15
        case .quickSale: return 0.75
        }
    }
}

// MARK: - ROI Calculation
struct ROICalculation {
    let buyPrice: Double
    let sellPrice: Double
    let fees: Double
    let profit: Double
    let roiPercentage: Double
    
    static func calculate(buyPrice: Double, sellPrice: Double) -> ROICalculation {
        let ebayFees = sellPrice * Configuration.defaultEbayFeeRate
        let paypalFees = sellPrice * Configuration.defaultPayPalFeeRate + 0.49
        let shippingCost = Configuration.defaultShippingCost
        let totalFees = ebayFees + paypalFees + shippingCost
        let profit = sellPrice - buyPrice - totalFees
        let roiPercentage = (profit / buyPrice) * 100
        
        return ROICalculation(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            fees: totalFees,
            profit: profit,
            roiPercentage: roiPercentage
        )
    }
    
    var isGoodDeal: Bool {
        return roiPercentage >= Configuration.minimumROIThreshold
    }
    
    var isPremiumDeal: Bool {
        return roiPercentage >= Configuration.preferredROIThreshold
    }
}

// MARK: - Authentication Check
struct AuthenticityCheck {
    let isAuthentic: Bool
    let confidence: Double
    let redFlags: [String]
    let authenticityMarkers: [String]
    
    var riskLevel: AuthenticityRisk {
        if !isAuthentic || confidence < 0.7 {
            return .high
        } else if confidence < 0.85 {
            return .medium
        } else {
            return .low
        }
    }
}

enum AuthenticityRisk: String {
    case low = "Low Risk"
    case medium = "Medium Risk"
    case high = "High Risk"
    
    var color: UIColor {
        switch self {
        case .low: return .systemGreen
        case .medium: return .systemOrange
        case .high: return .systemRed
        }
    }
}

// MARK: - Market Intelligence Extensions
struct MarketIntelligence {
    let demand: DemandLevel
    let competition: CompetitionLevel
    let priceStability: PriceStability
    let seasonalTrends: [String]
    let marketInsights: [String]
    
    enum PriceStability: String {
        case stable = "Stable"
        case volatile = "Volatile"
        case increasing = "Increasing"
        case decreasing = "Decreasing"
        
        var description: String {
            switch self {
            case .stable: return "Prices remain consistent"
            case .volatile: return "Prices fluctuate frequently"
            case .increasing: return "Prices trending upward"
            case .decreasing: return "Prices trending downward"
            }
        }
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

// MARK: - Service Health Monitoring
struct ServiceHealthStatus {
    let openAIConfigured: Bool
    let analysisWorking: Bool
    let overallHealthy: Bool
    let lastUpdated: Date
    
    var statusDescription: String {
        if overallHealthy {
            return "All systems operational"
        } else {
            var issues: [String] = []
            if !openAIConfigured { issues.append("OpenAI") }
            if !analysisWorking { issues.append("Analysis") }
            return "Issues with: \(issues.joined(separator: ", "))"
        }
    }
}

struct EbayServiceHealthStatus {
    let ebayConfigured: Bool
    let listingWorking: Bool
    let overallHealthy: Bool
    let lastUpdated: Date
    
    var statusDescription: String {
        if overallHealthy {
            return "eBay services operational"
        } else {
            var issues: [String] = []
            if !ebayConfigured { issues.append("eBay Auth") }
            if !listingWorking { issues.append("Listing") }
            return "eBay issues: \(issues.joined(separator: ", "))"
        }
    }
}

// MARK: - Data Extensions for Crypto
extension Data {
    func sha256() -> Data {
        let hashed = SHA256.hash(data: self)
        return Data(hashed)
    }
}

// MARK: - UI Color Extension
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}