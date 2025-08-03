//
//  EbayListingService.swift
//  ResellAI
//
//  Created by Alec on 8/3/25.
//


//
//  EbayListingService.swift
//  ResellAI
//
//  eBay Listing Service
//

import Foundation
import SwiftUI

class EbayListingService: ObservableObject {
    @Published var isListing = false
    @Published var listingProgress = 0.0
    @Published var currentStep = ""
    @Published var listingResult: EbayListingResult?
    @Published var error: String?
    
    private let ebayAuth = EbayAuthManager.shared
    
    private let listingSteps = [
        "Preparing listing data...",
        "Uploading images to eBay...",
        "Creating inventory item...",
        "Creating listing offer...",
        "Publishing to eBay..."
    ]
    
    // MARK: - Main Listing Function
    func createListing(item: InventoryItem, analysisResult: AnalysisResult, images: [UIImage]) async {
        await MainActor.run {
            isListing = true
            listingProgress = 0.0
            error = nil
            listingResult = nil
        }
        
        do {
            // Check eBay authentication
            guard ebayAuth.isAuthenticated else {
                throw ListingError.notAuthenticated
            }
            
            // Step 1: Prepare listing data
            await updateProgress(step: 0)
            let listingData = prepareListing(item: item, analysis: analysisResult)
            
            // Step 2: Upload images
            await updateProgress(step: 1)
            let imageURLs = await uploadImages(images)
            
            // Step 3: Create inventory item
            await updateProgress(step: 2)
            let inventoryResult = await createInventoryItem(listingData: listingData, imageURLs: imageURLs)
            
            // Step 4: Create offer
            await updateProgress(step: 3)
            let offerResult = await createOffer(sku: listingData.sku, price: listingData.price)
            
            // Step 5: Publish listing
            await updateProgress(step: 4)
            let publishResult = await publishListing(offerId: offerResult)
            
            // Complete listing
            let result = EbayListingResult(
                success: true,
                listingId: publishResult,
                listingURL: "https://www.ebay.com/itm/\(publishResult)",
                error: nil
            )
            
            await MainActor.run {
                self.listingResult = result
                self.listingProgress = 1.0
                self.isListing = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.listingResult = EbayListingResult(
                    success: false,
                    listingId: nil,
                    listingURL: nil,
                    error: error.localizedDescription
                )
                self.isListing = false
            }
        }
    }
    
    // MARK: - Prepare Listing Data
    private func prepareListing(item: InventoryItem, analysis: AnalysisResult) -> EbayListingData {
        let sku = generateSKU(for: item)
        let categoryId = getCategoryId(for: analysis.category)
        let conditionId = analysis.condition.ebayConditionId
        
        return EbayListingData(
            sku: sku,
            title: analysis.suggestedTitle,
            description: analysis.description,
            categoryId: categoryId,
            conditionId: conditionId,
            conditionDescription: analysis.condition.description,
            price: analysis.estimatedValue,
            currency: "USD",
            quantity: 1,
            imageURLs: [], // Will be populated after image upload
            brand: analysis.brand,
            size: item.size,
            color: item.colorway,
            packageWeightAndSize: nil,
            returnPolicy: createReturnPolicy(),
            fulfillmentPolicy: createFulfillmentPolicy(),
            paymentPolicy: createPaymentPolicy()
        )
    }
    
    // MARK: - Image Upload
    private func uploadImages(_ images: [UIImage]) async -> [String] {
        guard let accessToken = ebayAuth.accessToken else { return [] }
        
        var uploadedURLs: [String] = []
        
        for (index, image) in images.prefix(Configuration.ebayMaxImages).enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            
            let url = URL(string: "\(Configuration.currentEbayAPIBase)/sell/inventory/v1/bulk_upload_image")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.httpBody = imageData
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 201,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let imageId = json["imageId"] as? String {
                    
                    let imageURL = "\(Configuration.currentEbayAPIBase)/sell/inventory/v1/inventory_item/image/\(imageId)"
                    uploadedURLs.append(imageURL)
                }
            } catch {
                print("Failed to upload image \(index): \(error)")
            }
        }
        
        return uploadedURLs
    }
    
    // MARK: - Create Inventory Item
    private func createInventoryItem(listingData: EbayListingData, imageURLs: [String]) async throws -> String {
        guard let accessToken = ebayAuth.accessToken else {
            throw ListingError.notAuthenticated
        }
        
        let url = URL(string: "\(Configuration.currentEbayAPIBase)/sell/inventory/v1/inventory_item/\(listingData.sku)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let inventoryItem: [String: Any] = [
            "availability": [
                "shipToLocationAvailability": [
                    "quantity": listingData.quantity
                ]
            ],
            "condition": listingData.conditionId,
            "conditionDescription": listingData.conditionDescription,
            "product": [
                "title": listingData.title,
                "description": listingData.description,
                "aspects": [
                    "Brand": [listingData.brand],
                    "Size": [listingData.size],
                    "Color": [listingData.color]
                ],
                "brand": listingData.brand,
                "imageUrls": imageURLs
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: inventoryItem, options: .prettyPrinted)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ListingError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 || httpResponse.statusCode == 204 {
            return listingData.sku
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ListingError.apiError(errorMessage)
        }
    }
    
    // MARK: - Create Offer
    private func createOffer(sku: String, price: Double) async throws -> String {
        guard let accessToken = ebayAuth.accessToken else {
            throw ListingError.notAuthenticated
        }
        
        let url = URL(string: "\(Configuration.currentEbayAPIBase)/sell/inventory/v1/offer")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let offer: [String: Any] = [
            "sku": sku,
            "marketplaceId": "EBAY_US",
            "format": "FIXED_PRICE",
            "availableQuantity": 1,
            "pricingSummary": [
                "price": [
                    "value": String(format: "%.2f", price),
                    "currency": "USD"
                ]
            ],
            "listingDescription": "Item in excellent condition. Fast shipping with tracking.",
            "categoryId": Configuration.ebayCategoryMappings["Other"] ?? "267",
            "listingPolicies": [
                "fulfillmentPolicyId": "5774912000",
                "paymentPolicyId": "5774910000",
                "returnPolicyId": "5774908000"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: offer, options: .prettyPrinted)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ListingError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let offerId = json["offerId"] as? String {
                return offerId
            }
        }
        
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw ListingError.apiError(errorMessage)
    }
    
    // MARK: - Publish Listing
    private func publishListing(offerId: String) async throws -> String {
        guard let accessToken = ebayAuth.accessToken else {
            throw ListingError.notAuthenticated
        }
        
        let url = URL(string: "\(Configuration.currentEbayAPIBase)/sell/inventory/v1/offer/\(offerId)/publish/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ListingError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let listingId = json["listingId"] as? String {
                return listingId
            }
        }
        
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw ListingError.apiError(errorMessage)
    }
    
    // MARK: - Helper Functions
    private func updateProgress(step: Int) async {
        await MainActor.run {
            self.listingProgress = Double(step) / Double(self.listingSteps.count - 1)
            self.currentStep = step < self.listingSteps.count ? self.listingSteps[step] : "Completing listing..."
        }
        
        // Add small delay for UI feedback
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    private func generateSKU(for item: InventoryItem) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let cleanName = item.name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
        return "RESELL_\(cleanName)_\(timestamp)"
    }
    
    private func getCategoryId(for category: String) -> String {
        return Configuration.ebayCategoryMappings[category] ?? "267" // Default to Everything Else
    }
    
    private func createReturnPolicy() -> EbayReturnPolicy {
        return EbayReturnPolicy(
            returnsAccepted: true,
            returnPeriod: "Days_30",
            refundMethod: "MoneyBack",
            returnShippingCostPayer: "Buyer"
        )
    }
    
    private func createFulfillmentPolicy() -> EbayFulfillmentPolicy {
        let shippingService = EbayShippingService(
            shippingCarrierCode: "USPS",
            shippingServiceCode: "USPSGround",
            shippingCost: EbayAmount(value: "8.50", currency: "USD"),
            additionalShippingCost: nil,
            freeShipping: false,
            buyerResponsibleForShipping: false,
            buyerResponsibleForPickup: false
        )
        
        let shippingOption = EbayShippingOption(
            optionType: "DOMESTIC",
            costType: "FLAT_RATE",
            shippingServices: [shippingService]
        )
        
        return EbayFulfillmentPolicy(
            name: "Fast Shipping",
            shippingOptions: [shippingOption]
        )
    }
    
    private func createPaymentPolicy() -> EbayPaymentPolicy {
        let paymentMethod = EbayPaymentMethod(paymentMethodType: "PAYPAL")
        
        return EbayPaymentPolicy(
            name: "PayPal",
            paymentMethods: [paymentMethod]
        )
    }
}

// MARK: - Listing Errors
enum ListingError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case apiError(String)
    case imageUploadFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with eBay. Please sign in first."
        case .invalidResponse:
            return "Invalid response from eBay API"
        case .apiError(let message):
            return "eBay API Error: \(message)"
        case .imageUploadFailed:
            return "Failed to upload images to eBay"
        }
    }
}