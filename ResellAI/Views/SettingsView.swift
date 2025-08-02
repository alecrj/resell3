//
//  AppSettingsView.swift
//  ResellAI
//
//  Apple-Style Settings Interface
//

import SwiftUI
import MessageUI

// MARK: - Apple-Style App Settings View
struct AppSettingsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var googleSheetsService: GoogleSheetsService
    @EnvironmentObject var aiService: AIService
    
    @State private var showingExportSheet = false
    @State private var showingAPIConfiguration = false
    @State private var showingBusinessSettings = false
    @State private var showingDataManagement = false
    @State private var showingAbout = false
    @State private var showingMailComposer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Apple-style header
                    VStack(spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Configure your reselling business")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Quick stats
                    AppleSettingsStats(inventoryManager: inventoryManager)
                    
                    // Settings sections
                    VStack(spacing: 12) {
                        // Business Configuration
                        AppleSettingsSection(
                            title: "Business Configuration",
                            subtitle: "Margins, pricing, and business rules",
                            icon: "building.2.fill",
                            color: .blue
                        ) {
                            showingBusinessSettings = true
                        }
                        
                        // API Configuration
                        AppleSettingsSection(
                            title: "API Configuration",
                            subtitle: "OpenAI, Google Sheets, eBay",
                            icon: "network",
                            color: .green
                        ) {
                            showingAPIConfiguration = true
                        }
                        
                        // Data Management
                        AppleSettingsSection(
                            title: "Data Management",
                            subtitle: "Export, backup, sync",
                            icon: "externaldrive.fill",
                            color: .orange
                        ) {
                            showingDataManagement = true
                        }
                        
                        // Export Options
                        AppleSettingsSection(
                            title: "Export Inventory",
                            subtitle: "CSV, Google Sheets, eBay listings",
                            icon: "square.and.arrow.up.fill",
                            color: .purple
                        ) {
                            showingExportSheet = true
                        }
                        
                        // Support & Feedback
                        AppleSettingsSection(
                            title: "Support & Feedback",
                            subtitle: "Get help or send feedback",
                            icon: "questionmark.circle.fill",
                            color: .pink
                        ) {
                            showingMailComposer = true
                        }
                        
                        // About
                        AppleSettingsSection(
                            title: "About ResellAI",
                            subtitle: "Version and app information",
                            icon: "info.circle.fill",
                            color: .gray
                        ) {
                            showingAbout = true
                        }
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingBusinessSettings) {
            BusinessSettingsView()
                .environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showingAPIConfiguration) {
            APIConfigurationView()
                .environmentObject(aiService)
                .environmentObject(googleSheetsService)
        }
        .sheet(isPresented: $showingDataManagement) {
            DataManagementView()
                .environmentObject(inventoryManager)
                .environmentObject(googleSheetsService)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportOptionsView()
                .environmentObject(inventoryManager)
                .environmentObject(googleSheetsService)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                MailComposerView()
            } else {
                ContactSupportView()
            }
        }
    }
}

// MARK: - Apple Settings Stats
struct AppleSettingsStats: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        HStack(spacing: 16) {
            AppleSettingsStatCard(
                title: "Total Items",
                value: "\(inventoryManager.items.count)",
                color: .blue
            )
            
            AppleSettingsStatCard(
                title: "Total Value",
                value: "$\(String(format: "%.0f", inventoryManager.totalEstimatedValue))",
                color: .green
            )
            
            AppleSettingsStatCard(
                title: "Categories",
                value: "\(inventoryManager.getInventoryOverview().count)",
                color: .orange
            )
        }
    }
}

struct AppleSettingsStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Apple Settings Section
struct AppleSettingsSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with Apple styling
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Business Settings View
struct BusinessSettingsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var businessName = "Your Reselling Business"
    @State private var defaultMargin: Double = 200.0
    @State private var minimumROI: Double = 50.0
    @State private var defaultShippingCost: Double = 8.50
    @State private var autoGenerateListings = true
    @State private var trackPackaging = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Business Information") {
                    TextField("Business Name", text: $businessName)
                        .font(.system(size: 17, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Default Profit Margin")
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                            Text("\(String(format: "%.0f", defaultMargin))%")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $defaultMargin, in: 50...500, step: 25)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum ROI Target")
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                            Text("\(String(format: "%.0f", minimumROI))%")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        Slider(value: $minimumROI, in: 25...200, step: 25)
                            .accentColor(.green)
                    }
                }
                
                Section("Listing Defaults") {
                    HStack {
                        Text("Default Shipping Cost")
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                        Text("$")
                            .font(.system(size: 17, weight: .medium))
                        TextField("8.50", value: $defaultShippingCost, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Toggle("Auto-generate eBay Listings", isOn: $autoGenerateListings)
                        .font(.system(size: 17, weight: .medium))
                    
                    Toggle("Track Packaging Status", isOn: $trackPackaging)
                        .font(.system(size: 17, weight: .medium))
                }
                
                Section("Inventory Overview") {
                    AppleBusinessStat(title: "Total Items", value: "\(inventoryManager.items.count)")
                    AppleBusinessStat(title: "Categories Used", value: "\(inventoryManager.getInventoryOverview().count)")
                    AppleBusinessStat(
                        title: "Average ROI",
                        value: "\(String(format: "%.0f", inventoryManager.averageROI))%",
                        valueColor: inventoryManager.averageROI > 100 ? .green : .orange
                    )
                }
            }
            .navigationTitle("Business Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
        }
    }
}

struct AppleBusinessStat: View {
    let title: String
    let value: String
    let valueColor: Color
    
    init(title: String, value: String, valueColor: Color = .secondary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - API Configuration View
struct APIConfigurationView: View {
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var googleSheetsService: GoogleSheetsService
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("AI Analysis") {
                    AppleAPICard(
                        title: "OpenAI GPT-4",
                        description: "Powers item identification and analysis",
                        status: !Configuration.openAIKey.isEmpty ? "Configured" : "Not Configured",
                        isConfigured: !Configuration.openAIKey.isEmpty
                    )
                    
                    Text("Configure your OpenAI API key in environment variables")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Section("Data Sync") {
                    AppleAPICard(
                        title: "Google Sheets",
                        description: "Automatic inventory sync and backup",
                        status: googleSheetsService.isConnected ? "Connected" : "Not Connected",
                        isConfigured: googleSheetsService.isConnected
                    )
                    
                    if googleSheetsService.isConnected {
                        HStack {
                            Text("Last Sync")
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                            Text(googleSheetsService.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Test Google Sheets Connection") {
                        testGoogleSheetsConnection()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                }
                
                Section("eBay Integration") {
                    AppleAPICard(
                        title: "eBay API",
                        description: "Direct listing to eBay",
                        status: !Configuration.ebayAPIKey.isEmpty ? "Configured" : "Not Configured",
                        isConfigured: !Configuration.ebayAPIKey.isEmpty
                    )
                    
                    Text("eBay direct listing requires eBay Developer API access")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Section("Market Research") {
                    AppleAPICard(
                        title: "RapidAPI",
                        description: "Live market data and pricing",
                        status: !Configuration.rapidAPIKey.isEmpty ? "Configured" : "Not Configured",
                        isConfigured: !Configuration.rapidAPIKey.isEmpty
                    )
                }
                
                Section("Configuration Guide") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("To configure APIs:")
                            .font(.system(size: 16, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Set OPENAI_API_KEY in environment")
                            Text("2. Set GOOGLE_SCRIPT_URL for sheets sync")
                            Text("3. Set RAPID_API_KEY for market research")
                            Text("4. Configure eBay Developer Account for direct listing")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("API Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
        }
    }
    
    private func testGoogleSheetsConnection() {
        googleSheetsService.authenticate()
    }
}

struct AppleAPICard: View {
    let title: String
    let description: String
    let status: String
    let isConfigured: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                AppleStatusIndicator(status: status, isConfigured: isConfigured)
            }
        }
    }
}

struct AppleStatusIndicator: View {
    let status: String
    let isConfigured: Bool
    
    var body: some View {
        Text(status)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isConfigured ? .green : .red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isConfigured ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            )
    }
}

// MARK: - Data Management View
struct DataManagementView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var googleSheetsService: GoogleSheetsService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingClearDataAlert = false
    @State private var showingImportSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Backup & Sync") {
                    Button("Sync All Items to Google Sheets") {
                        googleSheetsService.syncAllItems(inventoryManager.items)
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                    .disabled(googleSheetsService.isSyncing)
                    
                    if googleSheetsService.isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(googleSheetsService.syncStatus)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Last Sync")
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                        Text(googleSheetsService.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Export Options") {
                    Button("Export CSV File") {
                        exportCSV()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                    
                    Button("Generate eBay Listing Batch") {
                        generateEbayListings()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                    
                    Button("Export Inventory Report") {
                        exportInventoryReport()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                }
                
                Section("Import Data") {
                    Button("Import from CSV") {
                        showingImportSheet = true
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                    
                    Text("Import inventory from CSV files")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Section("Storage Information") {
                    AppleStorageInfo(title: "Total Items", value: "\(inventoryManager.items.count)")
                    AppleStorageInfo(title: "Storage Size", value: "~\(estimateStorageSize()) MB")
                    AppleStorageInfo(title: "Photos Stored", value: "\(countPhotos())")
                }
                
                Section("Danger Zone") {
                    Button("Clear All Data") {
                        showingClearDataAlert = true
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all inventory data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingImportSheet) {
            CSVImportView()
                .environmentObject(inventoryManager)
        }
    }
    
    private func exportCSV() {
        let csv = inventoryManager.exportCSV()
        print("📄 CSV Export: \(csv.count) characters")
    }
    
    private func generateEbayListings() {
        print("📝 Generating eBay listings for \(inventoryManager.items.count) items")
    }
    
    private func exportInventoryReport() {
        print("📊 Generating inventory report")
    }
    
    private func estimateStorageSize() -> Int {
        let itemCount = inventoryManager.items.count
        let averageSize = 50
        return itemCount * averageSize / 1024
    }
    
    private func countPhotos() -> Int {
        return inventoryManager.items.reduce(0) { count, item in
            var photoCount = 0
            if item.imageData != nil { photoCount += 1 }
            if let additional = item.additionalImageData {
                photoCount += additional.count
            }
            return count + photoCount
        }
    }
    
    private func clearAllData() {
        UserDefaults.standard.removeObject(forKey: "SavedInventoryItems")
        UserDefaults.standard.removeObject(forKey: "CategoryCounters")
        inventoryManager.items.removeAll()
        print("🗑️ All data cleared")
    }
}

struct AppleStorageInfo: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Export Options View
struct ExportOptionsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var googleSheetsService: GoogleSheetsService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFormat = "CSV"
    @State private var includePhotos = false
    @State private var filterByStatus: ItemStatus?
    
    let exportFormats = ["CSV", "Google Sheets", "eBay Listings", "Inventory Report"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(exportFormats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Export Options") {
                    Toggle("Include Photos", isOn: $includePhotos)
                        .font(.system(size: 17, weight: .medium))
                    
                    Picker("Filter by Status", selection: $filterByStatus) {
                        Text("All Items").tag(ItemStatus?.none)
                        ForEach(ItemStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status as ItemStatus?)
                        }
                    }
                    .font(.system(size: 17, weight: .medium))
                }
                
                Section("Export Preview") {
                    let filteredItems = getFilteredItems()
                    
                    AppleExportStat(title: "Items to Export", value: "\(filteredItems.count)")
                    AppleExportStat(
                        title: "Total Value",
                        value: "$\(String(format: "%.2f", filteredItems.reduce(0) { $0 + $1.suggestedPrice }))",
                        valueColor: .green
                    )
                }
                
                Section {
                    Button("Export Now") {
                        performExport()
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Export Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
        }
    }
    
    private func getFilteredItems() -> [InventoryItem] {
        var items = inventoryManager.items
        
        if let status = filterByStatus {
            items = items.filter { $0.status == status }
        }
        
        return items
    }
    
    private func performExport() {
        let items = getFilteredItems()
        
        switch selectedFormat {
        case "CSV":
            exportToCSV(items)
        case "Google Sheets":
            exportToGoogleSheets(items)
        case "eBay Listings":
            exportToEbayListings(items)
        case "Inventory Report":
            exportToInventoryReport(items)
        default:
            break
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func exportToCSV(_ items: [InventoryItem]) {
        print("📄 Exporting \(items.count) items to CSV")
    }
    
    private func exportToGoogleSheets(_ items: [InventoryItem]) {
        print("📊 Syncing \(items.count) items to Google Sheets")
        googleSheetsService.syncAllItems(items)
    }
    
    private func exportToEbayListings(_ items: [InventoryItem]) {
        print("🏪 Generating eBay listings for \(items.count) items")
    }
    
    private func exportToInventoryReport(_ items: [InventoryItem]) {
        print("📋 Generating inventory report for \(items.count) items")
    }
}

struct AppleExportStat: View {
    let title: String
    let value: String
    let valueColor: Color
    
    init(title: String, value: String, valueColor: Color = .secondary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text("📱")
                            .font(.system(size: 80))
                        
                        Text("ResellAI")
                            .font(.system(size: 34, weight: .bold))
                        
                        Text("Ultimate Reselling Business Tool")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 20) {
                        AppleFeatureCard(
                            icon: "brain.head.profile",
                            title: "AI-Powered Analysis",
                            description: "Computer vision and GPT-4 analysis for instant item identification, condition assessment, and pricing."
                        )
                        
                        AppleFeatureCard(
                            icon: "scope",
                            title: "Smart Prospecting",
                            description: "Get instant max buy prices while sourcing. Know exactly what to pay before you buy."
                        )
                        
                        AppleFeatureCard(
                            icon: "archivebox.fill",
                            title: "Smart Inventory",
                            description: "Auto-organized inventory with smart codes, storage tracking, and profit analysis."
                        )
                        
                        AppleFeatureCard(
                            icon: "chart.bar.fill",
                            title: "Business Intelligence",
                            description: "Track profits, ROI, and performance with comprehensive analytics and reporting."
                        )
                        
                        AppleFeatureCard(
                            icon: "network",
                            title: "Seamless Integration",
                            description: "Direct integration with Google Sheets, eBay, and market research APIs."
                        )
                    }
                    
                    VStack(spacing: 16) {
                        Text("Built for serious resellers who want to:")
                            .font(.system(size: 20, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            AppleBulletPoint(text: "Maximize profits with AI-powered analysis")
                            AppleBulletPoint(text: "Streamline inventory management")
                            AppleBulletPoint(text: "Make smarter sourcing decisions")
                            AppleBulletPoint(text: "Scale their reselling business")
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct AppleFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct AppleBulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Supporting Views

// CSV Import View (placeholder)
struct CSVImportView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 16) {
                        Text("CSV Import")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("CSV import functionality coming soon")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// Mail Composer
struct MailComposerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setSubject("ResellAI Support Request")
        composer.setToRecipients(["support@resellai.app"])
        composer.setMessageBody("Hi ResellAI Team,\n\nI need help with:\n\n", isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// Contact Support View (when mail is not available)
struct ContactSupportView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 16) {
                        Text("Contact Support")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Email us at:")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("support@resellai.app")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}
