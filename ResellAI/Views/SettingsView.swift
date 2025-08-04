//
//  SettingsView.swift
//  ResellAI
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var ebayService = EbayService()
    @StateObject private var inventoryManager = InventoryManager()
    
    @State private var showingConfigStatus = false
    @State private var testingAPI = false
    @State private var apiTestResult: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                configurationSection
                ebaySection
                inventorySection
                debugSection
            }
            .navigationTitle("Settings")
            .onAppear {
                Configuration.validateConfiguration()
            }
        }
    }
    
    // MARK: - Configuration Section
    
    private var configurationSection: some View {
        Section("API Configuration") {
            ConfigRowView(
                title: "OpenAI",
                status: Configuration.openAIKey.isEmpty ? "Not Set" : "Configured",
                isConfigured: !Configuration.openAIKey.isEmpty
            )
            
            ConfigRowView(
                title: "RapidAPI",
                status: Configuration.rapidAPIKey.isEmpty ? "Not Set" : "Configured",
                isConfigured: !Configuration.rapidAPIKey.isEmpty
            )
            
            ConfigRowView(
                title: "Google Cloud",
                status: Configuration.googleCloudAPIKey.isEmpty ? "Not Set" : "Configured",
                isConfigured: !Configuration.googleCloudAPIKey.isEmpty
            )
            
            ConfigRowView(
                title: "eBay API",
                status: Configuration.isEbayConfigured ? "Configured" : "Not Set",
                isConfigured: Configuration.isEbayConfigured
            )
            
            Button("Show Configuration Status") {
                showingConfigStatus.toggle()
            }
            .sheet(isPresented: $showingConfigStatus) {
                ConfigurationStatusView()
            }
        }
    }
    
    // MARK: - eBay Section
    
    private var ebaySection: some View {
        Section("eBay Integration") {
            HStack {
                Text("Authentication")
                Spacer()
                if ebayService.isAuthenticated {
                    Text("Connected")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("Not Connected")
                        .foregroundColor(.red)
                }
            }
            
            if ebayService.isAuthenticated {
                Button("Disconnect eBay") {
                    ebayService.logout()
                }
                .foregroundColor(.red)
            } else {
                Button("Connect to eBay") {
                    if let authURL = ebayService.startOAuthFlow() {
                        UIApplication.shared.open(authURL)
                    }
                }
            }
            
            HStack {
                Text("Environment")
                Spacer()
                Text(Configuration.ebayEnvironment)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Inventory Section
    
    private var inventorySection: some View {
        Section("Inventory") {
            HStack {
                Text("Total Items")
                Spacer()
                Text("\(inventoryManager.totalItems)")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Listed Items")
                Spacer()
                Text("\(inventoryManager.listedItems.count)")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Sold Items")
                Spacer()
                Text("\(inventoryManager.soldItems.count)")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Total Value")
                Spacer()
                Text("$\(inventoryManager.totalValue, specifier: "%.2f")")
                    .fontWeight(.medium)
            }
            
            if inventoryManager.totalItems > 0 {
                Button("Clear All Inventory") {
                    inventoryManager.clearInventory()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
        Section("Debug & Testing") {
            Button(testingAPI ? "Testing..." : "Test API Connections") {
                testAPIConnections()
            }
            .disabled(testingAPI)
            
            if !apiTestResult.isEmpty {
                Text(apiTestResult)
                    .font(.caption)
                    .foregroundColor(apiTestResult.contains("✅") ? .green : .red)
            }
            
            Button("View Cost Estimates") {
                showCostEstimates()
            }
            
            Button("Print Debug Info") {
                Configuration.validateConfiguration()
                Configuration.printSetupInstructions()
            }
        }
    }
    
    // MARK: - Actions
    
    private func testAPIConnections() {
        testingAPI = true
        apiTestResult = ""
        
        Task {
            var results: [String] = []
            
            // Test OpenAI
            if !Configuration.openAIKey.isEmpty {
                results.append("✅ OpenAI: Key configured")
            } else {
                results.append("❌ OpenAI: Key missing")
            }
            
            // Test RapidAPI
            if !Configuration.rapidAPIKey.isEmpty {
                results.append("✅ RapidAPI: Key configured")
                
                // Test actual RapidAPI connection
                do {
                    let ebayService = EbayService()
                    let testComps = try await ebayService.searchSoldComps(
                        searchTerms: ["iPhone 15"],
                        category: "Electronics"
                    )
                    results.append("✅ RapidAPI: Connection successful (\(testComps.count) items found)")
                } catch {
                    results.append("❌ RapidAPI: Connection failed - \(error.localizedDescription)")
                }
                
            } else {
                results.append("❌ RapidAPI: Key missing")
            }
            
            // Test eBay
            if Configuration.isEbayConfigured {
                results.append("✅ eBay: API configured")
            } else {
                results.append("❌ eBay: API not configured")
            }
            
            await MainActor.run {
                apiTestResult = results.joined(separator: "\n")
                testingAPI = false
            }
        }
    }
    
    private func showCostEstimates() {
        let alert = UIAlertController(
            title: "API Cost Estimates",
            message: Configuration.estimateAPICosts(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
}

// MARK: - Configuration Row View

struct ConfigRowView: View {
    let title: String
    let status: String
    let isConfigured: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundColor(isConfigured ? .green : .red)
                .fontWeight(.medium)
            
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isConfigured ? .green : .red)
        }
    }
}

// MARK: - Configuration Status View

struct ConfigurationStatusView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("ResellAI Configuration")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Current Status: \(Configuration.configurationStatus)")
                        .font(.headline)
                        .foregroundColor(Configuration.isFullyConfigured ? .green : .orange)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Environment Variables:")
                            .font(.headline)
                        
                        EnvironmentVariableRow(name: "OPENAI_API_KEY", isSet: !Configuration.openAIKey.isEmpty)
                        EnvironmentVariableRow(name: "RAPID_API_KEY", isSet: !Configuration.rapidAPIKey.isEmpty)
                        EnvironmentVariableRow(name: "GOOGLE_CLOUD_API_KEY", isSet: !Configuration.googleCloudAPIKey.isEmpty)
                        EnvironmentVariableRow(name: "GOOGLE_SCRIPT_URL", isSet: !Configuration.googleScriptURL.isEmpty)
                        EnvironmentVariableRow(name: "SPREADSHEET_ID", isSet: !Configuration.spreadsheetID.isEmpty)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("eBay Configuration:")
                            .font(.headline)
                        
                        ConfigDetailRow(key: "App ID", value: Configuration.ebayAPIKey.isEmpty ? "Not Set" : "Set")
                        ConfigDetailRow(key: "Client Secret", value: Configuration.ebayClientSecret.isEmpty ? "Not Set" : "Set")
                        ConfigDetailRow(key: "Dev ID", value: Configuration.ebayDevId.isEmpty ? "Not Set" : "Set")
                        ConfigDetailRow(key: "Environment", value: Configuration.ebayEnvironment)
                        ConfigDetailRow(key: "Redirect URI", value: Configuration.ebayRedirectURI)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("App Settings:")
                            .font(.headline)
                        
                        ConfigDetailRow(key: "Max Photos", value: "\(Configuration.maxPhotos)")
                        ConfigDetailRow(key: "Default Shipping", value: "$\(Configuration.defaultShippingCost, specifier: "%.2f")")
                        ConfigDetailRow(key: "eBay Fee Rate", value: "\(Configuration.defaultEbayFeeRate * 100, specifier: "%.2f")%")
                        ConfigDetailRow(key: "PayPal Fee Rate", value: "\(Configuration.defaultPayPalFeeRate * 100, specifier: "%.2f")%")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by sheet
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EnvironmentVariableRow: View {
    let name: String
    let isSet: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(isSet ? "✅ Set" : "❌ Missing")
                .foregroundColor(isSet ? .green : .red)
        }
    }
}

struct ConfigDetailRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
