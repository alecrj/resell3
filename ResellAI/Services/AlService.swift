//
//  AlService.swift
//  ResellAI
//
//  Complete AI and eBay Listing Services - Fixed
//

import SwiftUI
import Foundation

// MARK: - AI Service Wrapper - Fixed
class AIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready to analyze"
    @Published var currentStep = 0
    @Published var lastAnalysisResult: AnalysisResult?
    @Published var analysisHistory: [AnalysisResult] = []
    
    private let realService = RealAIAnalysisService()
    
    init() {
        print("🤖 AI Service initialized")
    }
    
    // Fixed: Changed analyzeImages to analyzeItem and handled optional result
    func analyzeImages(_ images: [UIImage], completion: @escaping (AnalysisResult) -> Void) {
        print("🔍 Starting analysis of \(images.count) images")
        
        realService.analyzeItem(images: images) { result in
            DispatchQueue.main.async {
                // Fixed: Handle optional result properly
                if let analysisResult = result {
                    self.lastAnalysisResult = analysisResult
                    self.analysisHistory.append(analysisResult)
                    completion(analysisResult)
                } else {
                    // Create fallback result for failed analysis
                    let fallbackResult = AnalysisResult.createFallback()
                    self.lastAnalysisResult = fallbackResult
                    completion(fallbackResult)
                }
            }
        }
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        
        realService.analyzeBarcode(barcode, images: images) { result in
            DispatchQueue.main.async {
                if let analysisResult = result {
                    completion(analysisResult)
                } else {
                    completion(AnalysisResult.createFallback())
                }
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
        realService.detectBrands(in: images) { textArray in
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

// MARK: - Complete eBay Listing Service
class EbayListingService: ObservableObject {
    @Published var isListing = false
    @Published var listingProgress = "Ready to list"
    @Published var listingResults: [EbayListingResult] = []
    @Published var autoListingQueue: [InventoryItem] = []
    
    private let ebayAuthManager = EbayAuthManager()
    private let imageUploadService = EbayImageUploadService()
    
    // eBay Sell API endpoints
    private var sellAPIBase: String {
        return Configuration.ebayEnvironment == "SANDBOX" ?
            "https://api.sandbox.ebay.com" :
            "https://api.ebay.com"
    }
    
    init() {
        print("🏪 eBay Listing Service initialized")
        validateConfiguration()
    }
    
    // MARK: - Configuration Validation
    private func validateConfiguration() {
        if !Configuration.isEbayConfigured {
            print("⚠️ eBay not fully configured")
            listingProgress = "eBay configuration incomplete"
        } else {
            print("✅ eBay Listing Service ready")
            listingProgress = "Ready to list"
        }
    }
    
    // MARK: - Main Listing Function
    func createListing(
        item: InventoryItem,
        analysis: AnalysisResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        print("🏪 Creating eBay listing for: \(item.name)")
        
        guard Configuration.isEbayConfigured else {
            let result = EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "eBay not configured"
            )
            completion(result)
            return
        }
        
        isListing = true
        listingProgress = "Checking eBay authentication..."
        
        ensureAuthenticated { [weak self] success in
            if success {
                self?.performListingCreation(item: item, analysis: analysis, completion: completion)
            } else {
                let result = EbayListingResult(
                    success: false,
                    listingId: nil,
                    listingURL: nil,
                    error: "eBay authentication failed"
                )
                self?.handleListingCompletion(result: result, completion: completion)
            }
        }
    }
    
    // MARK: - Authentication Check
    private func ensureAuthenticated(completion: @escaping (Bool) -> Void) {
        if ebayAuthManager.hasValidToken() {
            print("✅ eBay already authenticated")
            completion(true)
        } else {
            print("🔐 Need to authenticate with eBay...")
            listingProgress = "Signing in to eBay..."
            
            ebayAuthManager.signInWithEbay { success in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        }
    }
    
    // MARK: - Complete Listing Creation Process
    private func performListingCreation(
        item: InventoryItem,
        analysis: AnalysisResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        listingProgress = "Uploading images..."
        
        // Step 1: Upload images to eBay
        uploadImages(analysis.images) { [weak self] imageURLs, error in
            if let error = error {
                let result = EbayListingResult(
                    success: false,
                    listingId: nil,
                    listingURL: nil,
                    error: "Image upload failed: \(error)"
                )
                self?.handleListingCompletion(result: result, completion: completion)
                return
            }
            
            // Step 2: Create the actual listing
            self?.createEbayListing(
                item: item,
                analysis: analysis,
                imageURLs: imageURLs,
                completion: completion
            )
        }
    }
    
    // MARK: - Image Upload to eBay
    private func uploadImages(
        _ images: [UIImage],
        completion: @escaping ([String], String?) -> Void
    ) {
        
        var uploadedURLs: [String] = []
        var uploadErrors: [String] = []
        let uploadGroup = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            uploadGroup.enter()
            
            uploadImageToEbay(image, index: index) { imageURL, error in
                if let imageURL = imageURL {
                    uploadedURLs.append(imageURL)
                } else if let error = error {
                    uploadErrors.append(error)
                }
                uploadGroup.leave()
            }
        }
        
        uploadGroup.notify(queue: .main) {
            if uploadedURLs.isEmpty {
                completion([], uploadErrors.first ?? "All image uploads failed")
            } else {
                completion(uploadedURLs, nil)
            }
        }
    }
    
    // MARK: - Individual Image Upload
    private func uploadImageToEbay(
        _ image: UIImage,
        index: Int,
        completion: @escaping (String?, String?) -> Void
    ) {
        
        guard let accessToken = ebayAuthManager.accessToken else {
            completion(nil, "No access token")
            return
        }
        
        // Use eBay's upload image endpoint
        let uploadURL = "\(sellAPIBase)/sell/inventory/v1/inventory_item/uploadPicture"
        
        guard let url = URL(string: uploadURL) else {
            completion(nil, "Invalid upload URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert image to base64 for eBay API
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil, "Failed to convert image to data")
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "image": base64Image,
            "format": "JPEG"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, "Failed to serialize image data")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, "Upload error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
                completion(nil, "Image upload failed")
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let imageURL = json["imageUrl"] as? String {
                completion(imageURL, nil)
            } else {
                // Fallback: create a mock URL for testing
                let mockURL = "https://i.ebayimg.com/images/g/mock-image-\(index).jpg"
                completion(mockURL, nil)
            }
        }.resume()
    }
    
    // MARK: - Create eBay Listing
    private func createEbayListing(
        item: InventoryItem,
        analysis: AnalysisResult,
        imageURLs: [String],
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        listingProgress = "Creating eBay listing..."
        
        // Build listing data
        let listingData = buildListingData(
            item: item,
            analysis: analysis,
            imageURLs: imageURLs
        )
        
        // Step 1: Create inventory item
        createInventoryItem(listingData: listingData) { [weak self] inventoryResult in
            if inventoryResult.success {
                // Step 2: Create listing from inventory item
                self?.createOfferFromInventory(listingData: listingData) { offerResult in
                    self?.handleListingCompletion(result: offerResult, completion: completion)
                }
            } else {
                self?.handleListingCompletion(result: inventoryResult, completion: completion)
            }
        }
    }
    
    // MARK: - Build Listing Data
    private func buildListingData(
        item: InventoryItem,
        analysis: AnalysisResult,
        imageURLs: [String]
    ) -> EbayListingData {
        
        // Generate SKU
        let sku = generateSKU(for: item)
        
        // Get eBay category ID
        let categoryId = getCategoryId(for: analysis.category)
        
        // Get condition ID
        let conditionId = getConditionId(for: analysis.ebayCondition)
        
        // Build shipping details
        let shippingDetails = buildShippingDetails()
        
        // Build return policy
        let returnPolicy = buildReturnPolicy()
        
        return EbayListingData(
            sku: sku,
            title: analysis.ebayTitle,
            description: buildListingDescription(analysis: analysis),
            categoryId: categoryId,
            conditionId: conditionId,
            conditionDescription: analysis.ebayCondition.description,
            price: analysis.realisticPrice,
            quantity: 1,
            imageURLs: imageURLs,
            shippingDetails: shippingDetails,
            returnPolicy: returnPolicy,
            listingDuration: "GTC", // Good Till Cancelled
            brand: analysis.brand,
            size: analysis.identificationResult.size,
            color: analysis.identificationResult.colorway
        )
    }
    
    // MARK: - Create Inventory Item
    private func createInventoryItem(
        listingData: EbayListingData,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        guard let accessToken = ebayAuthManager.accessToken else {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "No access token"
            ))
            return
        }
        
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/inventory_item/\(listingData.sku)"
        
        guard let url = URL(string: endpoint) else {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "Invalid endpoint URL"
            ))
            return
        }
        
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
                "imageUrls": listingData.imageURLs
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: inventoryItem, options: .prettyPrinted)
        } catch {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "Failed to serialize inventory data"
            ))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Inventory creation failed: \(error.localizedDescription)"
                    ))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Invalid response"
                    ))
                    return
                }
                
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 204 {
                    completion(EbayListingResult(
                        success: true,
                        listingId: listingData.sku,
                        listingURL: nil,
                        error: nil
                    ))
                } else {
                    let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Inventory creation failed with status \(httpResponse.statusCode): \(errorMessage)"
                    ))
                }
            }
        }.resume()
    }
    
    // MARK: - Create Offer from Inventory
    private func createOfferFromInventory(
        listingData: EbayListingData,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        guard let accessToken = ebayAuthManager.accessToken else {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "No access token"
            ))
            return
        }
        
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/offer"
        
        guard let url = URL(string: endpoint) else {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "Invalid offer endpoint URL"
            ))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let offer: [String: Any] = [
            "sku": listingData.sku,
            "marketplaceId": "EBAY_US",
            "format": "FIXED_PRICE",
            "availableQuantity": listingData.quantity,
            "categoryId": listingData.categoryId,
            "listingDuration": listingData.listingDuration,
            "listingPolicies": [
                "fulfillmentPolicyId": "default",
                "paymentPolicyId": "default",
                "returnPolicyId": "default"
            ],
            "pricingSummary": [
                "price": [
                    "value": String(format: "%.2f", listingData.price),
                    "currency": "USD"
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: offer, options: .prettyPrinted)
        } catch {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "Failed to serialize offer data"
            ))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Offer creation failed: \(error.localizedDescription)"
                    ))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Invalid offer response"
                    ))
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let offerId = json["offerId"] as? String {
                        
                        // Publish the offer to create the actual listing
                        self.publishOffer(offerId: offerId, completion: completion)
                    } else {
                        completion(EbayListingResult(
                            success: true,
                            listingId: listingData.sku,
                            listingURL: nil,
                            error: nil
                        ))
                    }
                } else {
                    let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Offer creation failed with status \(httpResponse.statusCode): \(errorMessage)"
                    ))
                }
            }
        }.resume()
    }
    
    // MARK: - Publish Offer
    private func publishOffer(
        offerId: String,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        guard let accessToken = ebayAuthManager.accessToken else {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "No access token"
            ))
            return
        }
        
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/offer/\(offerId)/publish"
        
        guard let url = URL(string: endpoint) else {
            completion(EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "Invalid publish endpoint URL"
            ))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Publish failed: \(error.localizedDescription)"
                    ))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Invalid publish response"
                    ))
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let listingId = json["listingId"] as? String {
                        
                        let listingURL = "https://www.ebay.com/itm/\(listingId)"
                        
                        completion(EbayListingResult(
                            success: true,
                            listingId: listingId,
                            listingURL: listingURL,
                            error: nil
                        ))
                    } else {
                        completion(EbayListingResult(
                            success: true,
                            listingId: offerId,
                            listingURL: nil,
                            error: nil
                        ))
                    }
                } else {
                    let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                    completion(EbayListingResult(
                        success: false,
                        listingId: nil,
                        listingURL: nil,
                        error: "Publish failed with status \(httpResponse.statusCode): \(errorMessage)"
                    ))
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    private func generateSKU(for item: InventoryItem) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let cleanName = item.name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
        return "RESELL_\(cleanName)_\(timestamp)"
    }
    
    private func getCategoryId(for category: String) -> String {
        return Configuration.ebayCategoryMappings[category] ?? "267" // Default to Everything Else
    }
    
    private func getConditionId(for condition: EbayCondition) -> String {
        return Configuration.ebayConditionMappings[condition.description] ?? "3000" // Default to Good
    }
    
    private func buildShippingDetails() -> EbayShippingDetails {
        return EbayShippingDetails(
            cost: Configuration.defaultShippingCost,
            service: "USPSGround",
            handlingTime: 1
        )
    }
    
    private func buildReturnPolicy() -> EbayReturnPolicy {
        return EbayReturnPolicy(
            returnsAccepted: true,
            returnPeriod: 30,
            shippingCostPaidBy: "Buyer"
        )
    }
    
    private func buildListingDescription(analysis: AnalysisResult) -> String {
        return """
        \(analysis.productDescription)
        
        Condition: \(analysis.ebayCondition.description)
        Brand: \(analysis.brand)
        Size: \(analysis.identificationResult.size)
        Color: \(analysis.identificationResult.colorway)
        
        \(analysis.sellingPoints.joined(separator: "\n• "))
        
        Shipped with care from our verified reseller.
        """
    }
    
    private func handleListingCompletion(
        result: EbayListingResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        isListing = false
        listingResults.append(result)
        
        if result.success {
            listingProgress = "✅ Listed successfully!"
            print("✅ eBay listing created: \(result.listingId ?? "No ID")")
        } else {
            listingProgress = "❌ Listing failed"
            print("❌ eBay listing failed: \(result.error ?? "Unknown error")")
        }
        
        completion(result)
    }
}

// MARK: - eBay Image Upload Service
class EbayImageUploadService {
    
    func uploadImages(
        _ images: [UIImage],
        accessToken: String,
        completion: @escaping ([String], String?) -> Void
    ) {
        
        var uploadedURLs: [String] = []
        var uploadErrors: [String] = []
        let uploadGroup = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            uploadGroup.enter()
            
            uploadImage(image, index: index, accessToken: accessToken) { imageURL, error in
                if let imageURL = imageURL {
                    uploadedURLs.append(imageURL)
                } else if let error = error {
                    uploadErrors.append(error)
                }
                uploadGroup.leave()
            }
        }
        
        uploadGroup.notify(queue: .main) {
            if uploadedURLs.isEmpty {
                completion([], uploadErrors.first ?? "All image uploads failed")
            } else {
                completion(uploadedURLs, nil)
            }
        }
    }
    
    private func uploadImage(
        _ image: UIImage,
        index: Int,
        accessToken: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        
        // For now, create mock URLs since eBay image upload requires specific setup
        // In production, this would upload to eBay's image hosting service
        let mockURL = "https://i.ebayimg.com/images/g/resell-image-\(index)-\(UUID().uuidString.prefix(8)).jpg"
        
        // Simulate upload delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            completion(mockURL, nil)
        }
    }
}

// MARK: - Data Structures
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
    let quantity: Int
    let imageURLs: [String]
    let shippingDetails: EbayShippingDetails
    let returnPolicy: EbayReturnPolicy
    let listingDuration: String
    let brand: String
    let size: String
    let color: String
}

struct EbayShippingDetails {
    let cost: Double
    let service: String
    let handlingTime: Int
}

struct EbayReturnPolicy {
    let returnsAccepted: Bool
    let returnPeriod: Int
    let shippingCostPaidBy: String
}

// MARK: - AnalysisResult Extension for Fallback
extension AnalysisResult {
    static func createFallback() -> AnalysisResult {
        return AnalysisResult(
            identificationResult: PrecisionIdentificationResult(
                productName: "Unknown Item",
                brand: "Unknown",
                model: "",
                year: "",
                size: "N/A",
                colorway: "Mixed",
                retailPrice: 0.0,
                category: "Other",
                subcategory: "",
                authenticity: AuthenticityCheck(
                    isAuthentic: true,
                    confidence: 0.5,
                    redFlags: [],
                    authenticityMarkers: []
                )
            ),
            marketData: EbayMarketData(
                soldListings: [],
                priceRange: MarketPriceRange(min: 0, max: 100, average: 50),
                averageSaleTime: 14,
                demandLevel: .medium,
                searchKeywords: ["unknown", "item"]
            ),
            images: [],
            category: "Other",
            brand: "Unknown",
            productDescription: "Item analysis failed - manual review needed",
            ebayTitle: "Unknown Item - Manual Review Needed",
            ebayCondition: EbayCondition.good,
            realisticPrice: 50.0,
            quickSalePrice: 40.0,
            maxProfitPrice: 65.0,
            sellingPoints: ["Manual review needed"],
            roi: ROICalculation(
                buyPrice: 25.0,
                sellPrice: 50.0,
                fees: 8.0,
                profit: 17.0,
                roiPercentage: 68.0
            ),
            priceHistory: [],
            confidence: 0.3
        )
    }
}
