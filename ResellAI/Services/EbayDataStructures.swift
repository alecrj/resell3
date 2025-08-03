//
//  EbayDataStructures.swift
//  ResellAI
//
//  eBay API Response Structures Only - NO Business Models
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
}

// MARK: - eBay OAuth PKCE
struct PKCECodeChallenge {
    let codeVerifier: String
    let codeChallenge: String
    
    init() {
        self.codeVerifier = PKCECodeChallenge.generateCodeVerifier()
        self.codeChallenge = PKCECodeChallenge.generateCodeChallenge(from: codeVerifier)
    }
    
    private static func generateCodeVerifier() -> String {
        let length = 128
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        let randomData = (0..<length).map { _ in allowedChars.randomElement()! }
        return String(randomData)
    }
    
    private static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - eBay Finding API Structures
struct EbayFindingResponse: Codable {
    let findCompletedItemsResponse: [EbayFindingResult]
}

struct EbayFindingResult: Codable {
    let ack: [String]
    let searchResult: [EbaySearchResult]
    let paginationOutput: [EbayPaginationOutput]?
}

struct EbaySearchResult: Codable {
    let count: String
    let item: [EbayFoundItem]
}

struct EbayFoundItem: Codable {
    let itemId: [String]
    let title: [String]
    let sellingStatus: [EbaySellingStatus]
    let shippingInfo: [EbayShippingInfo]?
    let condition: [EbayItemCondition]?
    let listingInfo: [EbayListingInfo]?
    let galleryURL: [String]?
    let viewItemURL: [String]?
}

struct EbaySellingStatus: Codable {
    let currentPrice: [EbayPrice]
    let convertedCurrentPrice: [EbayPrice]?
    let timeLeft: [String]?
    let sellingState: [String]
}

struct EbayPrice: Codable {
    let value: String
    let currencyId: String
    
    enum CodingKeys: String, CodingKey {
        case value = "__value__"
        case currencyId = "@currencyId"
    }
}

struct EbayShippingInfo: Codable {
    let shippingServiceCost: [EbayPrice]?
    let shippingType: [String]?
    let expeditedShipping: [String]?
}

struct EbayItemCondition: Codable {
    let conditionId: [String]
    let conditionDisplayName: [String]
}

struct EbayListingInfo: Codable {
    let bestOfferEnabled: [String]?
    let buyItNowAvailable: [String]?
    let startTime: [String]?
    let endTime: [String]?
    let listingType: [String]?
    let watchCount: [String]?
}

struct EbayPaginationOutput: Codable {
    let pageNumber: [String]
    let entriesPerPage: [String]
    let totalPages: [String]
    let totalEntries: [String]
}

// MARK: - eBay Category Structures
struct EbayCategoryResponse: Codable {
    let categoryCount: Int
    let categories: [EbayCategory]
}

struct EbayCategory: Codable {
    let categoryId: String
    let categoryName: String
    let categoryLevel: Int
    let parentCategoryId: String?
}

// MARK: - eBay Upload Response
struct EbayUploadResponse: Codable {
    let imageId: String?
    let errors: [EbayError]?
    let warnings: [EbayWarning]?
}
