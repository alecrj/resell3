//
//  Configuration.swift
//  ResellAI
//
//  Complete API Configuration with Environment Variables
//

import Foundation

// MARK: - Complete App Configuration with Environment Variables
struct Configuration {
    
    // MARK: - API Keys from Environment Variables
    static let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    
    static let googleScriptURL = ProcessInfo.processInfo.environment["GOOGLE_SCRIPT_URL"] ?? ""
    
    static let rapidAPIKey = ProcessInfo.processInfo.environment["RAPID_API_KEY"] ?? ""
    
    static let spreadsheetID = ProcessInfo.processInfo.environment["SPREADSHEET_ID"] ?? ""
    
    static let googleCloudAPIKey = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"] ?? ""
    
    // MARK: - eBay OAuth 2.0 Configuration
    static let ebayAPIKey = "AlecRodr-resell-PRD-d0bc91504-be3e553a"
    static let ebayClientSecret = "PRD-0bc91504af12-57f0-49aa-8bb7-763a"
    static let ebayDevId = "7b77d928-4c43-4d2c-ad86-a0ea503437ae"
    static let ebayEnvironment = "PRODUCTION" // Using production for real business
    
    // eBay OAuth endpoints
    static let ebayRedirectURI = "resellai://auth/ebay"
    
    // MARK: - API Endpoints
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // eBay API endpoints
    static let ebayProductionAPIBase = "https://api.ebay.com"
    static let ebaySandboxAPIBase = "https://api.sandbox.ebay.com"
    static let ebayAuthBase = "https://auth.ebay.com"
    static let ebaySandboxAuthBase = "https://auth.sandbox.ebay.com"
    
    // eBay Finding API (for sold comps)
    static let ebayFindingAPIBase = "https://svcs.ebay.com/services/search/FindingService/v1"
    
    // MARK: - App Configuration
    static let appName = "ResellAI"
    static let version = "1.0.0"
    static let maxPhotos = 8
    static let defaultShippingCost = 8.50
    static let defaultEbayFeeRate = 0.1325
    static let defaultPayPalFeeRate = 0.0349
    
    // MARK: - Business Rules
    static let minimumROIThreshold = 50.0
    static let preferredROIThreshold = 100.0
    static let maxBuyPriceMultiplier = 0.6
    static let quickSalePriceMultiplier = 0.85
    static let premiumPriceMultiplier = 1.15
    
    // MARK: - eBay Specific Settings
    static let ebayMaxImages = 8
    static let ebayDefaultShippingTime = 3 // business days
    static let ebayDefaultReturnPeriod = 30 // days
    static let ebayListingDuration = 7 // days
    
    // MARK: - Rate Limiting
    static let ebayAPICallsPerSecond = 5
    static let openAIMaxTokens = 3000
    static let rapidAPICallsPerMinute = 100
    
    // MARK: - Configuration Validation
    static var isFullyConfigured: Bool {
        return !openAIKey.isEmpty &&
               !googleScriptURL.isEmpty &&
               !rapidAPIKey.isEmpty &&
               !spreadsheetID.isEmpty &&
               !ebayAPIKey.isEmpty &&
               !ebayClientSecret.isEmpty
    }
    
    static var isEbayConfigured: Bool {
        return !ebayAPIKey.isEmpty && !ebayClientSecret.isEmpty && !ebayDevId.isEmpty
    }
    
    static var configurationStatus: String {
        if isFullyConfigured {
            return "All systems ready"
        } else {
            var missing: [String] = []
            if openAIKey.isEmpty { missing.append("OpenAI") }
            if googleScriptURL.isEmpty { missing.append("Google Sheets") }
            if rapidAPIKey.isEmpty { missing.append("RapidAPI") }
            if ebayAPIKey.isEmpty { missing.append("eBay API Key") }
            if ebayClientSecret.isEmpty { missing.append("eBay Client Secret") }
            if ebayDevId.isEmpty { missing.append("eBay Dev ID") }
            return "Missing: \(missing.joined(separator: ", "))"
        }
    }
    
    // MARK: - Development Helpers
    static func validateConfiguration() {
        print("🔧 ResellAI Configuration Status:")
        print("✅ OpenAI: \(openAIKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ Google Sheets: \(googleScriptURL.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ RapidAPI: \(rapidAPIKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ Spreadsheet: \(spreadsheetID.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ Google Cloud: \(googleCloudAPIKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ eBay API Key: \(ebayAPIKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ eBay Client Secret: \(ebayClientSecret.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ eBay Dev ID: \(ebayDevId.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ Environment: \(ebayEnvironment)")
        print("📊 Overall Status: \(configurationStatus)")
        
        if isFullyConfigured {
            print("🚀 All APIs configured - ResellAI ready!")
        } else {
            print("⚠️ Some APIs need configuration")
        }
        
        if isEbayConfigured {
            print("🎉 eBay Integration Ready!")
            print("• App ID: \(ebayAPIKey)")
            print("• Environment: \(ebayEnvironment)")
            print("• Redirect URI: \(ebayRedirectURI)")
            print("• Finding API: \(ebayFindingAPIBase)")
        }
        
        // Print environment variable status
        print("\n🔧 Environment Variables:")
        print("• OPENAI_API_KEY: \(ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil ? "Set" : "Missing")")
        print("• GOOGLE_SCRIPT_URL: \(ProcessInfo.processInfo.environment["GOOGLE_SCRIPT_URL"] != nil ? "Set" : "Missing")")
        print("• RAPID_API_KEY: \(ProcessInfo.processInfo.environment["RAPID_API_KEY"] != nil ? "Set" : "Missing")")
        print("• SPREADSHEET_ID: \(ProcessInfo.processInfo.environment["SPREADSHEET_ID"] != nil ? "Set" : "Missing")")
        print("• GOOGLE_CLOUD_API_KEY: \(ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"] != nil ? "Set" : "Missing")")
    }
    
    // MARK: - Cost Estimates
    static func estimateAPICosts() -> String {
        return """
        📊 API Cost Estimates (per analysis):
        • OpenAI GPT-4o: ~$0.03-0.08
        • eBay Finding API: Free (5,000 calls/day)
        • RapidAPI calls: ~$0.001-0.01
        • Google Sheets: Free
        
        💰 Estimated monthly cost for 100 analyses: $3-9
        
        🛍️ eBay Listing Fees:
        • Insertion Fee: $0.35 per listing
        • Final Value Fee: 13.25% of total amount
        • PayPal Fee: 3.49% + $0.49
        """
    }
    
    // MARK: - eBay Category Mappings
    static let ebayCategoryMappings: [String: String] = [
        "Sneakers": "15709", // Athletic Shoes
        "Shoes": "15709",
        "Clothing": "11450", // Clothing, Shoes & Accessories > Men's Clothing
        "Electronics": "58058", // Cell Phones & Smartphones
        "Accessories": "169291", // Fashion Accessories
        "Home": "11700", // Home & Garden
        "Collectibles": "1", // Collectibles
        "Books": "267", // Books & Magazines
        "Toys": "220", // Toys & Hobbies
        "Sports": "888", // Sporting Goods
        "Other": "267" // Everything Else
    ]
    
    // MARK: - eBay Condition Mappings
    static let ebayConditionMappings: [String: String] = [
        "New with tags": "1000",
        "New without tags": "1500",
        "New other": "1750",
        "Like New": "2000",
        "Excellent": "2500",
        "Very Good": "3000",
        "Good": "4000",
        "Acceptable": "5000",
        "For parts or not working": "7000"
    ]
    
    // MARK: - Default eBay Listing Settings
    static let defaultEbaySettings: [String: Any] = [
        "listingDuration": "Days_7",
        "listingType": "FixedPriceItem",
        "country": "US",
        "currency": "USD",
        "conditionDescription": "See photos and description for details",
        "returnPolicy": [
            "returnsAccepted": true,
            "returnPeriod": "Days_30",
            "returnsAcceptedDescription": "30 day returns accepted",
            "shippingCostPaidBy": "Buyer"
        ],
        "shippingDetails": [
            "shippingType": "Flat",
            "shippingServiceOptions": [
                [
                    "shippingService": "USPSGround",
                    "shippingServiceCost": defaultShippingCost,
                    "shippingTimeMin": 2,
                    "shippingTimeMax": 8
                ]
            ]
        ]
    ]
    
    // MARK: - Environment Helpers
    static var currentEbayAPIBase: String {
        return ebayEnvironment == "SANDBOX" ? ebaySandboxAPIBase : ebayProductionAPIBase
    }
    
    static var currentEbayAuthBase: String {
        return ebayEnvironment == "SANDBOX" ? ebaySandboxAuthBase : ebayAuthBase
    }
    
    // MARK: - eBay OAuth Scopes (Required for your app)
    static let ebayRequiredScopes: [String] = [
        "https://api.ebay.com/oauth/api_scope/sell.marketing",
        "https://api.ebay.com/oauth/api_scope/sell.inventory",
        "https://api.ebay.com/oauth/api_scope/sell.account",
        "https://api.ebay.com/oauth/api_scope/sell.fulfillment"
    ]
    
    // MARK: - Setup Instructions
    static func printSetupInstructions() {
        print("""
        🚀 ResellAI eBay Sold Comp Integration Setup:
        
        ✅ COMPLETED STEPS:
        • eBay Developer Account: ✅ Created
        • eBay Finding API Access: ✅ Available (free)
        • Credentials Retrieved: ✅ Done
        • Configuration Updated: ✅ Done
        • Environment Variables: \(isFullyConfigured ? "✅ Set" : "⚠️ Needs Setup")
        
        📋 TO TEST REAL EBAY COMPS:
        1. Ensure environment variables are set:
           • OPENAI_API_KEY=\(openAIKey.isEmpty ? "MISSING" : "SET")
           • GOOGLE_SCRIPT_URL=\(googleScriptURL.isEmpty ? "MISSING" : "SET")
           • RAPID_API_KEY=\(rapidAPIKey.isEmpty ? "MISSING" : "SET")
           • SPREADSHEET_ID=\(spreadsheetID.isEmpty ? "MISSING" : "SET")
           • GOOGLE_CLOUD_API_KEY=\(googleCloudAPIKey.isEmpty ? "MISSING" : "SET")
        
        2. Build and run the app
        
        3. Test eBay comp lookup:
           • Analyze any item with photos
           • GPT will identify the product
           • Real eBay API will search for sold comps
           • Pricing will be based on actual sales data
        
        📱 Your current setup:
        • eBay App ID: ✅ Set (Production)
        • Finding API: ✅ Ready
        • Environment: \(ebayEnvironment)
        • Rate Limit: \(ebayAPICallsPerSecond) calls/second
        
        🎉 READY TO SEARCH REAL EBAY SOLD COMPS!
        """)
    }
    
    // MARK: - Testing Helper
    static func testEbayConfig() -> String {
        return """
        🧪 eBay Configuration Test:
        
        Finding API Endpoint: \(ebayFindingAPIBase)
        App ID: \(ebayAPIKey.isEmpty ? "❌ Missing" : "✅ Set")
        Status: \(isEbayConfigured ? "✅ Ready" : "❌ Not Configured")
        
        Test Search Query Example:
        POST \(ebayFindingAPIBase)
        OPERATION-NAME=findCompletedItems
        SECURITY-APPNAME=\(ebayAPIKey)
        keywords=nike air force 1
        itemFilter(0).name=SoldItemsOnly
        itemFilter(0).value=true
        
        Expected Result: JSON with sold listings from last 30 days
        """
    }
}
