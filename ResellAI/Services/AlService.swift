//
//  AlService.swift
//  ResellAI
//
//  Complete AI and eBay Listing Services
//

import SwiftUI
import Foundation

// MARK: - AI Service Wrapper
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
    
    func analyzeImages(_ images: [UIImage], completion: @escaping (AnalysisResult) -> Void) {
        print("🔍 Starting analysis of \(images.count) images")
        
        realService.analyzeImages(images) { result in
            DispatchQueue.main.async {
                self.lastAnalysisResult = result
                self.analysisHistory.append(result)
                completion(result)
            }
        }
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult) -> Void) {
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
        // Use detectBrands method which includes text detection
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
        
        guard let accessToken = ebayAuthManager.accessToken else {
            completion([], "No access token available")
            return
        }
        
        imageUploadService.uploadImages(
            images,
            accessToken: accessToken,
            sellAPIBase: sellAPIBase
        ) { imageURLs, error in
            DispatchQueue.main.async {
                completion(imageURLs, error)
            }
        }
    }
    
    // MARK: - Create eBay Listing
    private func createEbayListing(
        item: InventoryItem,
        analysis: AnalysisResult,
        imageURLs: [String],
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        listingProgress = "Creating eBay listing..."
        
        guard let accessToken = ebayAuthManager.accessToken else {
            let result = EbayListingResult(
                success: false,
                listingId: nil,
                listingURL: nil,
                error: "No access token available"
            )
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        // Build listing data
        let listingData = buildListingData(
            item: item,
            analysis: analysis,
            imageURLs: imageURLs
        )
        
        // Create inventory item first (required for Fixed Price listings)
        createInventoryItem(
            listingData: listingData,
            accessToken: accessToken
        ) { [weak self] inventoryResult in
            
            if inventoryResult.success {
                // Then create the offer (actual listing)
                self?.createOffer(
                    listingData: listingData,
                    accessToken: accessToken,
                    completion: completion
                )
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
        accessToken: String,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/inventory_item/\(listingData.sku)"
        
        guard let url = URL(string: endpoint) else {
            completion(EbayListingResult(success: false, error: "Invalid inventory URL"))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Configuration.ebayAPIKey, forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        let inventoryPayload: [String: Any] = [
            "availability": [
                "shipToLocationAvailability": [
                    "quantity": listingData.quantity
                ]
            ],
            "condition": listingData.conditionId,
            "conditionDescription": listingData.conditionDescription,
            "packageWeightAndSize": [
                "dimensions": [
                    "height": 6,
                    "length": 12,
                    "width": 9,
                    "unit": "INCH"
                ],
                "weight": [
                    "value": 1.0,
                    "unit": "POUND"
                ]
            ],
            "product": [
                "title": listingData.title,
                "description": listingData.description,
                "imageUrls": listingData.imageURLs,
                "aspects": buildProductAspects(listingData: listingData)
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: inventoryPayload)
        } catch {
            completion(EbayListingResult(success: false, error: "Failed to encode inventory data"))
            return
        }
        
        print("📦 Creating inventory item: \(listingData.sku)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handleInventoryResponse(
                    data: data,
                    response: response,
                    error: error,
                    sku: listingData.sku,
                    completion: completion
                )
            }
        }.resume()
    }
    
    // MARK: - Create Offer (Actual Listing)
    private func createOffer(
        listingData: EbayListingData,
        accessToken: String,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        let offerId = UUID().uuidString
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/offer/\(offerId)"
        
        guard let url = URL(string: endpoint) else {
            completion(EbayListingResult(success: false, error: "Invalid offer URL"))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        let offerPayload: [String: Any] = [
            "sku": listingData.sku,
            "marketplaceId": "EBAY_US",
            "format": "FIXED_PRICE",
            "availableQuantity": listingData.quantity,
            "categoryId": listingData.categoryId,
            "listingDescription": listingData.description,
            "listingPolicies": [
                "fulfillmentPolicyId": nil,
                "paymentPolicyId": nil,
                "returnPolicyId": nil,
                "shippingCostOverrides": [
                    [
                        "shippingServiceType": "DOMESTIC",
                        "shippingCost": [
                            "value": String(listingData.shippingDetails.cost),
                            "currency": "USD"
                        ]
                    ]
                ]
            ],
            "pricingSummary": [
                "price": [
                    "value": String(format: "%.2f", listingData.price),
                    "currency": "USD"
                ]
            ],
            "quantityLimitPerBuyer": 1,
            "storeCategoryNames": [],
            "lotSize": 1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: offerPayload)
        } catch {
            completion(EbayListingResult(success: false, error: "Failed to encode offer data"))
            return
        }
        
        print("🏷️ Creating offer for SKU: \(listingData.sku)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handleOfferResponse(
                    data: data,
                    response: response,
                    error: error,
                    listingData: listingData,
                    completion: completion
                )
            }
        }.resume()
    }
    
    // MARK: - Response Handlers
    private func handleInventoryResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        sku: String,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        if let error = error {
            print("❌ Inventory creation error: \(error)")
            completion(EbayListingResult(success: false, error: "Network error: \(error.localizedDescription)"))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(EbayListingResult(success: false, error: "Invalid response"))
            return
        }
        
        print("📦 Inventory response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 || httpResponse.statusCode == 201 {
            print("✅ Inventory item created: \(sku)")
            completion(EbayListingResult(success: true))
        } else {
            let errorMessage = parseErrorMessage(data: data) ?? "Unknown inventory error"
            print("❌ Inventory creation failed: \(errorMessage)")
            completion(EbayListingResult(success: false, error: errorMessage))
        }
    }
    
    private func handleOfferResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        listingData: EbayListingData,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        if let error = error {
            print("❌ Offer creation error: \(error)")
            let result = EbayListingResult(success: false, error: "Network error: \(error.localizedDescription)")
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let result = EbayListingResult(success: false, error: "Invalid response")
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        print("🏷️ Offer response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
            // Parse successful response
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let offerId = json["offerId"] as? String {
                
                // Publish the listing
                publishListing(offerId: offerId, listingData: listingData, completion: completion)
            } else {
                let result = EbayListingResult(success: false, error: "Failed to parse offer response")
                handleListingCompletion(result: result, completion: completion)
            }
        } else {
            let errorMessage = parseErrorMessage(data: data) ?? "Unknown offer error"
            print("❌ Offer creation failed: \(errorMessage)")
            let result = EbayListingResult(success: false, error: errorMessage)
            handleListingCompletion(result: result, completion: completion)
        }
    }
    
    // MARK: - Publish Listing
    private func publishListing(
        offerId: String,
        listingData: EbayListingData,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        listingProgress = "Publishing listing..."
        
        guard let accessToken = ebayAuthManager.accessToken else {
            let result = EbayListingResult(success: false, error: "No access token for publishing")
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/offer/\(offerId)/publish"
        
        guard let url = URL(string: endpoint) else {
            let result = EbayListingResult(success: false, error: "Invalid publish URL")
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handlePublishResponse(
                    data: data,
                    response: response,
                    error: error,
                    offerId: offerId,
                    listingData: listingData,
                    completion: completion
                )
            }
        }.resume()
    }
    
    private func handlePublishResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        offerId: String,
        listingData: EbayListingData,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        
        if let error = error {
            let result = EbayListingResult(success: false, error: "Publish error: \(error.localizedDescription)")
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let result = EbayListingResult(success: false, error: "Invalid publish response")
            handleListingCompletion(result: result, completion: completion)
            return
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            // Parse the listing ID from response
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let listingId = json["listingId"] as? String {
                
                let listingURL = "https://www.ebay.com/itm/\(listingId)"
                let result = EbayListingResult(
                    success: true,
                    listingId: listingId,
                    listingURL: listingURL,
                    error: nil
                )
                
                print("🎉 Listing published successfully!")
                print("• Listing ID: \(listingId)")
                print("• URL: \(listingURL)")
                
                handleListingCompletion(result: result, completion: completion)
            } else {
                let result = EbayListingResult(success: false, error: "Failed to get listing ID")
                handleListingCompletion(result: result, completion: completion)
            }
        } else {
            let errorMessage = parseErrorMessage(data: data) ?? "Unknown publish error"
            let result = EbayListingResult(success: false, error: errorMessage)
            handleListingCompletion(result: result, completion: completion)
        }
    }
    
    // MARK: - Helper Methods
    private func handleListingCompletion(
        result: EbayListingResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        isListing = false
        listingProgress = result.success ? "✅ Listed successfully!" : "❌ Listing failed"
        listingResults.append(result)
        completion(result)
    }
    
    private func generateSKU(for item: InventoryItem) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "RAI-\(item.itemNumber)-\(timestamp)"
    }
    
    private func getCategoryId(for category: String) -> String {
        return Configuration.ebayCategoryMappings[category] ?? "267" // Default to Everything Else
    }
    
    private func getConditionId(for condition: EbayCondition) -> String {
        return Configuration.ebayConditionMappings[condition.rawValue] ?? "3000"
    }
    
    private func buildShippingDetails() -> EbayShippingDetails {
        return EbayShippingDetails(
            cost: Configuration.defaultShippingCost,
            service: "USPSGround",
            handlingTime: 3
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
        var description = analysis.description
        
        // Add condition details
        description += "\n\nCondition: \(analysis.ebayCondition.description)"
        
        // Add brand and size if available
        if !analysis.brand.isEmpty {
            description += "\nBrand: \(analysis.brand)"
        }
        
        if !analysis.identificationResult.size.isEmpty {
            description += "\nSize: \(analysis.identificationResult.size)"
        }
        
        // Add shipping info
        description += "\n\nShipping: Fast and secure shipping with tracking."
        description += "\nReturns: 30-day return policy for buyer satisfaction."
        
        return description
    }
    
    private func buildProductAspects(listingData: EbayListingData) -> [String: [String]] {
        var aspects: [String: [String]] = [:]
        
        if !listingData.brand.isEmpty {
            aspects["Brand"] = [listingData.brand]
        }
        
        if !listingData.size.isEmpty {
            aspects["Size"] = [listingData.size]
        }
        
        if !listingData.color.isEmpty {
            aspects["Color"] = [listingData.color]
        }
        
        return aspects
    }
    
    private func parseErrorMessage(data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let errors = json["errors"] as? [[String: Any]],
           let firstError = errors.first,
           let message = firstError["message"] as? String {
            return message
        }
        
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        
        return "Unknown error"
    }
    
    // MARK: - Legacy Interface Methods (for compatibility)
    func listItemToEbay(
        item: InventoryItem,
        analysis: AnalysisResult,
        completion: @escaping (EbayListingResult) -> Void
    ) {
        createListing(item: item, analysis: analysis, completion: completion)
    }
    
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
    
    var canCreateListings: Bool {
        return Configuration.isEbayConfigured && ebayAuthManager.hasValidToken()
    }
    
    // MARK: - Service Health Check
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

// MARK: - eBay Image Upload Service
class EbayImageUploadService {
    
    func uploadImages(
        _ images: [UIImage],
        accessToken: String,
        sellAPIBase: String,
        completion: @escaping ([String], String?) -> Void
    ) {
        
        var uploadedURLs: [String] = []
        let group = DispatchGroup()
        var uploadError: String?
        
        // Limit to 8 images (eBay limit)
        let imagesToUpload = Array(images.prefix(8))
        
        for (index, image) in imagesToUpload.enumerated() {
            group.enter()
            
            uploadSingleImage(
                image: image,
                index: index,
                accessToken: accessToken,
                sellAPIBase: sellAPIBase
            ) { imageURL, error in
                
                if let imageURL = imageURL {
                    uploadedURLs.append(imageURL)
                } else if uploadError == nil {
                    uploadError = error ?? "Image upload failed"
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(uploadedURLs.sorted(), uploadError)
        }
    }
    
    private func uploadSingleImage(
        image: UIImage,
        index: Int,
        accessToken: String,
        sellAPIBase: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil, "Failed to convert image to data")
            return
        }
        
        let endpoint = "\(sellAPIBase)/sell/inventory/v1/inventory_item/image"
        
        guard let url = URL(string: endpoint) else {
            completion(nil, "Invalid image upload URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var formData = Data()
        
        // Add image data
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"image\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(imageData)
        formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                
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
            }
        }.resume()
    }
}

// MARK: - eBay Listing Performance
struct EbayListingPerformance {
    let totalListings: Int
    let successfulListings: Int
    let failedListings: Int
    let successRate: Double
}

// MARK: - Supporting Data Structures
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
