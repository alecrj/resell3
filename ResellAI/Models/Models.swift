//
//  Models.swift
//  ResellAI
//
//  Consolidated data models for the entire app
//

import Foundation
import SwiftUI

// MARK: - Core Item Model
struct ItemAnalysis: Codable, Identifiable {
    let id = UUID()
    let title: String
    let brand: String
    let category: String
    let condition: ItemCondition
    let description: String
    let confidence: Double
    let suggestedPrice: Double
    let quickSalePrice: Double
    let premiumPrice: Double
    let ebayComps: [EbayComp]
    let photos: [Data]
    let createdAt: Date
    
    init(title: String, brand: String, category: String, condition: ItemCondition, description: String, confidence: Double, suggestedPrice: Double, quickSalePrice: Double, premiumPrice: Double, ebayComps: [EbayComp], photos: [Data]) {
        self.title = title
        self.brand = brand
        self.category = category
        self.condition = condition
        self.description = description
        self.confidence = confidence
        self.suggestedPrice = suggestedPrice
        self.quickSalePrice = quickSalePrice
        self.premiumPrice = premiumPrice
        self.ebayComps = ebayComps
        self.photos = photos
        self.createdAt = Date()
    }
}

// MARK: - Item Condition
enum ItemCondition: String, CaseIterable, Codable {
    case newWithTags = "New with tags"
    case newWithoutTags = "New without tags"
    case newOther = "New other"
    case likeNew = "Like New"
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case acceptable = "Acceptable"
    case forParts = "For parts or not working"
    
    var ebayConditionID: String {
        switch self {
        case .newWithTags: return "1000"
        case .newWithoutTags: return "1500"
        case .newOther: return "1750"
        case .likeNew: return "2000"
        case .excellent: return "2500"
        case .veryGood: return "3000"
        case .good: return "4000"
        case .acceptable: return "5000"
        case .forParts: return "7000"
        }
    }
    
    var description: String {
        switch self {
        case .newWithTags: return "Brand new with original tags attached"
        case .newWithoutTags: return "Brand new without tags"
        case .newOther: return "New condition with minor imperfections"
        case .likeNew: return "Used once or twice, like new condition"
        case .excellent: return "Excellent condition with minimal wear"
        case .veryGood: return "Very good condition with light wear"
        case .good: return "Good condition with normal wear"
        case .acceptable: return "Acceptable condition with noticeable wear"
        case .forParts: return "Item not working or for parts only"
        }
    }
}

// MARK: - eBay Comp Data
struct EbayComp: Codable, Identifiable {
    let id = UUID()
    let title: String
    let price: Double
    let condition: String
    let soldDate: Date
    let url: String
    let imageURL: String?
    let shippingCost: Double
    let totalPrice: Double
    
    init(title: String, price: Double, condition: String, soldDate: Date, url: String, imageURL: String? = nil, shippingCost: Double = 0.0) {
        self.title = title
        self.price = price
        self.condition = condition
        self.soldDate = soldDate
        self.url = url
        self.imageURL = imageURL
        self.shippingCost = shippingCost
        self.totalPrice = price + shippingCost
    }
}

// MARK: - Pricing Strategy
enum PricingStrategy: String, CaseIterable {
    case quickSale = "Quick Sale"
    case competitive = "Competitive"
    case premium = "Premium"
    
    var multiplier: Double {
        switch self {
        case .quickSale: return 0.85
        case .competitive: return 1.0
        case .premium: return 1.15
        }
    }
    
    var description: String {
        switch self {
        case .quickSale: return "Price to sell within 3-7 days"
        case .competitive: return "Market rate pricing"
        case .premium: return "Higher price for patient sellers"
        }
    }
}

// MARK: - eBay Listing Data
struct EbayListing: Codable {
    let title: String
    let description: String
    let price: Double
    let categoryID: String
    let conditionID: String
    let photos: [Data]
    let shippingCost: Double
    let returnPolicy: EbayReturnPolicy
    let itemSpecifics: [String: String]
    
    init(from analysis: ItemAnalysis, price: Double) {
        self.title = analysis.title
        self.description = analysis.description
        self.price = price
        self.categoryID = Self.getCategoryID(for: analysis.category)
        self.conditionID = analysis.condition.ebayConditionID
        self.photos = analysis.photos
        self.shippingCost = Configuration.defaultShippingCost
        self.returnPolicy = EbayReturnPolicy.default
        self.itemSpecifics = [
            "Brand": analysis.brand,
            "Condition": analysis.condition.rawValue,
            "Category": analysis.category
        ]
    }
    
    private static func getCategoryID(for category: String) -> String {
        return Configuration.ebayCategoryMappings[category] ?? "267"
    }
}

// MARK: - eBay Return Policy
struct EbayReturnPolicy: Codable {
    let returnsAccepted: Bool
    let returnPeriod: String
    let returnsAcceptedDescription: String
    let shippingCostPaidBy: String
    
    static let `default` = EbayReturnPolicy(
        returnsAccepted: true,
        returnPeriod: "Days_30",
        returnsAcceptedDescription: "30 day returns accepted",
        shippingCostPaidBy: "Buyer"
    )
}

// MARK: - eBay Auth Models
struct EbayAuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let createdAt: Date
    
    var isExpired: Bool {
        let expirationDate = createdAt.addingTimeInterval(TimeInterval(expiresIn))
        return Date() >= expirationDate
    }
}

// MARK: - eBay User Profile (Fixed)
struct EbayUserProfile: Codable {
    let userId: String
    let username: String
    let email: String?
    let registrationDate: String?
    let registrationMarketplaceId: String
    
    init(userId: String, username: String, email: String? = nil, registrationDate: String? = nil, registrationMarketplaceId: String = "EBAY_US") {
        self.userId = userId
        self.username = username
        self.email = email
        self.registrationDate = registrationDate
        self.registrationMarketplaceId = registrationMarketplaceId
    }
}

// MARK: - eBay Token Response
struct EbayTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}

// MARK: - eBay Listing Capabilities (Fixed)
struct EbayListingCapabilities: Codable {
    let canList: Bool
    let maxPhotos: Int
    let maxTitleLength: Int
    let supportedFormats: [String]
    let supportedCategories: [String]
    let sellerLevel: String
    
    init(canList: Bool, maxPhotos: Int, maxTitleLength: Int = 80, supportedFormats: [String], supportedCategories: [String], sellerLevel: String) {
        self.canList = canList
        self.maxPhotos = maxPhotos
        self.maxTitleLength = maxTitleLength
        self.supportedFormats = supportedFormats
        self.supportedCategories = supportedCategories
        self.sellerLevel = sellerLevel
    }
}

// MARK: - API Response Models
struct OpenAIAnalysisResponse: Codable {
    let title: String
    let brand: String
    let category: String
    let condition: String
    let description: String
    let confidence: Double
    let keyFeatures: [String]
    let searchTerms: [String]
}

// MARK: - Error Types
enum ResellAIError: LocalizedError {
    case invalidImage
    case analysisError(String)
    case ebayAuthError(String)
    case ebaySearchError(String)
    case ebayListingError(String)
    case networkError(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid or corrupted image"
        case .analysisError(let message):
            return "Analysis failed: \(message)"
        case .ebayAuthError(let message):
            return "eBay authentication failed: \(message)"
        case .ebaySearchError(let message):
            return "eBay search failed: \(message)"
        case .ebayListingError(let message):
            return "eBay listing failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var currentAnalysis: ItemAnalysis?
    @Published var selectedPricingStrategy: PricingStrategy = .competitive
    @Published var isAnalyzing = false
    @Published var isPostingToEbay = false
    @Published var ebayAuthToken: EbayAuthToken?
    @Published var recentAnalyses: [ItemAnalysis] = []
    @Published var errorMessage: String?
    
    var isEbayAuthenticated: Bool {
        guard let token = ebayAuthToken else { return false }
        return !token.isExpired
    }
    
    func addAnalysis(_ analysis: ItemAnalysis) {
        currentAnalysis = analysis
        recentAnalyses.insert(analysis, at: 0)
        if recentAnalyses.count > 50 {
            recentAnalyses.removeLast()
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func setError(_ error: ResellAIError) {
        errorMessage = error.localizedDescription
    }
}
