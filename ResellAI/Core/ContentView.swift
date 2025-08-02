import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

// MARK: - Clean Main Content View
struct ContentView: View {
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var aiService = AIService()
    @StateObject private var googleSheetsService = GoogleSheetsService()
    @StateObject private var ebayListingService = EbayListingService()
    
    @State private var isProspectingMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Clean Header
            CleanHeader(isProspectingMode: $isProspectingMode)
            
            // Main Content
            if isProspectingMode {
                ProspectingView()
                    .environmentObject(inventoryManager)
                    .environmentObject(aiService)
            } else {
                BusinessTabView()
                    .environmentObject(inventoryManager)
                    .environmentObject(aiService)
                    .environmentObject(googleSheetsService)
                    .environmentObject(ebayListingService)
            }
        }
        .onAppear {
            initializeServices()
        }
    }
    
    private func initializeServices() {
        Configuration.validateConfiguration()
        googleSheetsService.authenticate()
        print("🚀 ResellAI Ready - \(Configuration.configurationStatus)")
    }
}

// MARK: - Clean Header Design
struct CleanHeader: View {
    @Binding var isProspectingMode: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with logo and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ResellAI")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                    
                    Text("Ultimate Reselling Tool")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Clean status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Configuration.isFullyConfigured ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(Configuration.isFullyConfigured ? "Ready" : "Setup")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Configuration.isFullyConfigured ? .green : .orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((Configuration.isFullyConfigured ? Color.green : Color.orange).opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            
            // Mode Toggle
            CleanModeToggle(isProspectingMode: $isProspectingMode)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .top)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
                .opacity(0.3),
            alignment: .bottom
        )
    }
}

// MARK: - Clean Mode Toggle
struct CleanModeToggle: View {
    @Binding var isProspectingMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ModeButton(
                title: "Business",
                icon: "building.2.fill",
                isSelected: !isProspectingMode
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isProspectingMode = false
                }
            }
            
            ModeButton(
                title: "Prospect",
                icon: "scope",
                isSelected: isProspectingMode
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isProspectingMode = true
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
            .padding(2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Clean Tab View
struct BusinessTabView: View {
    var body: some View {
        TabView {
            CleanAnalysisView()
                .tabItem {
                    Image(systemName: "viewfinder")
                    Text("Analyze")
                }
            
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Dashboard")
                }
            
            SmartInventoryListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("Inventory")
                }
            
            InventoryOrganizationView()
                .tabItem {
                    Image(systemName: "archivebox.fill")
                    Text("Storage")
                }
            
            AppSettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .accentColor(.accentColor)
    }
}

// MARK: - Clean Analysis View
struct CleanAnalysisView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var googleSheetsService: GoogleSheetsService
    @EnvironmentObject var ebayListingService: EbayListingService
    
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var analysisResult: AnalysisResult?
    @State private var showingItemForm = false
    @State private var showingDirectListing = false
    @State private var showingBarcodeLookup = false
    @State private var scannedBarcode: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Clean header
                    VStack(spacing: 16) {
                        HStack {
                            Text("Item Analysis")
                                .font(.system(size: 32, weight: .bold))
                            Spacer()
                        }
                        
                        if !Configuration.isFullyConfigured {
                            CleanWarningBanner(
                                message: "Some APIs need configuration",
                                actionText: "Check Settings",
                                onAction: { }
                            )
                        }
                        
                        // Clean progress indicator
                        if aiService.isAnalyzing {
                            CleanProgressCard(
                                progress: Double(aiService.currentStep) / Double(aiService.totalSteps),
                                message: aiService.analysisProgress,
                                onCancel: { resetAnalysis() }
                            )
                        }
                    }
                    
                    // Photo section
                    if !capturedImages.isEmpty {
                        CleanPhotoGallery(images: $capturedImages)
                    } else {
                        CleanPhotoPlaceholder {
                            showingCamera = true
                        }
                    }
                    
                    // Action buttons
                    CleanActionButtons(
                        hasPhotos: !capturedImages.isEmpty,
                        isAnalyzing: aiService.isAnalyzing,
                        isConfigured: Configuration.isFullyConfigured,
                        onCamera: { showingCamera = true },
                        onLibrary: { showingPhotoLibrary = true },
                        onBarcode: { showingBarcodeLookup = true },
                        onAnalyze: { analyzeItem() },
                        onReset: { resetAnalysis() }
                    )
                    
                    // Results
                    if let result = analysisResult {
                        CleanAnalysisResult(analysis: result) {
                            showingItemForm = true
                        } onDirectList: {
                            showingDirectListing = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { photos in
                appendImages(photos)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPicker { photos in
                appendImages(photos)
            }
        }
        .sheet(isPresented: $showingItemForm) {
            if let result = analysisResult {
                ItemFormView(analysis: result, onSave: saveItem)
                    .environmentObject(inventoryManager)
            }
        }
        .sheet(isPresented: $showingDirectListing) {
            if let result = analysisResult {
                DirectEbayListingView(analysis: result)
                    .environmentObject(ebayListingService)
            }
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            BarcodeScannerView(scannedCode: $scannedBarcode)
                .onDisappear {
                    if let barcode = scannedBarcode {
                        analyzeBarcode(barcode)
                    }
                }
        }
    }
    
    // Performance optimized methods
    private func appendImages(_ photos: [UIImage]) {
        let optimizedPhotos = photos.compactMap { image -> UIImage? in
            return optimizeImage(image)
        }
        capturedImages.append(contentsOf: optimizedPhotos)
        analysisResult = nil
    }
    
    private func optimizeImage(_ image: UIImage) -> UIImage? {
        let maxSize: CGFloat = 1024
        let size = image.size
        
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let optimizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return optimizedImage
    }
    
    private func analyzeItem() {
        guard !capturedImages.isEmpty else { return }
        
        aiService.analyzeItem(capturedImages) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
            }
        }
    }
    
    private func analyzeBarcode(_ barcode: String) {
        aiService.analyzeBarcode(barcode, images: capturedImages) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
            }
        }
    }
    
    private func saveItem(_ item: InventoryItem) {
        let savedItem = inventoryManager.addItem(item)
        googleSheetsService.uploadItem(savedItem)
        showingItemForm = false
        resetAnalysis()
    }
    
    private func resetAnalysis() {
        capturedImages = []
        analysisResult = nil
        scannedBarcode = nil
    }
}

// MARK: - Clean UI Components

struct CleanWarningBanner: View {
    let message: String
    let actionText: String
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(actionText, action: onAction)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CleanProgressCard: View {
    let progress: Double
    let message: String
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analyzing...")
                        .font(.system(size: 20, weight: .bold))
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel", action: onCancel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .scaleEffect(y: 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }
}

struct CleanPhotoGallery: View {
    @Binding var images: [UIImage]
    @State private var selectedIndex = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Main photo
            TabView(selection: $selectedIndex) {
                ForEach(0..<images.count, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .cornerRadius(16)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 300)
            
            // Controls
            HStack {
                Text("\(images.count) photo\(images.count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: deleteCurrentPhoto) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }
    
    private func deleteCurrentPhoto() {
        if images.count > 1 {
            images.remove(at: selectedIndex)
            if selectedIndex >= images.count {
                selectedIndex = images.count - 1
            }
        } else {
            images.removeAll()
            selectedIndex = 0
        }
    }
}

struct CleanPhotoPlaceholder: View {
    let onTakePhotos: () -> Void
    
    var body: some View {
        Button(action: onTakePhotos) {
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 8) {
                    Text("Take Photos")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("Multiple angles improve accuracy")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .foregroundColor(.accentColor.opacity(0.3))
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.03))
            )
        }
        .buttonStyle(CleanButtonStyle())
    }
}

struct CleanActionButtons: View {
    let hasPhotos: Bool
    let isAnalyzing: Bool
    let isConfigured: Bool
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onBarcode: () -> Void
    let onAnalyze: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Photo capture buttons
            HStack(spacing: 12) {
                CleanActionButton(
                    icon: "camera.fill",
                    title: "Camera",
                    color: .accentColor,
                    action: onCamera
                )
                
                CleanActionButton(
                    icon: "photo.on.rectangle",
                    title: "Photos",
                    color: .green,
                    action: onLibrary
                )
                
                CleanActionButton(
                    icon: "barcode.viewfinder",
                    title: "Scan",
                    color: .orange,
                    action: onBarcode
                )
            }
            
            // Analysis button
            if hasPhotos {
                Button(action: onAnalyze) {
                    HStack(spacing: 8) {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Analyzing...")
                        } else {
                            Image(systemName: "brain.head.profile")
                            Text("Analyze Item")
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isConfigured ? Color.accentColor : Color.gray)
                    )
                }
                .disabled(isAnalyzing || !isConfigured)
                .buttonStyle(CleanButtonStyle())
                
                // Reset button
                if !isAnalyzing {
                    Button("Start Over", action: onReset)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .buttonStyle(CleanButtonStyle())
                }
            }
        }
    }
}

struct CleanActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(CleanButtonStyle())
    }
}

struct CleanAnalysisResult: View {
    let analysis: AnalysisResult
    let onAddToInventory: () -> Void
    let onDirectList: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(analysis.itemName)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(2)
                        
                        if !analysis.brand.isEmpty {
                            Text(analysis.brand)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                        
                        Text("\(String(format: "%.0f", analysis.confidence.overall * 100))% confident")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("$\(String(format: "%.0f", analysis.realisticPrice))")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Market Price")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Quick stats
                HStack(spacing: 12) {
                    CleanStatChip(label: "Condition", value: analysis.actualCondition, color: .blue)
                    CleanStatChip(label: "Sales", value: "\(analysis.soldListings.count)", color: .purple)
                    CleanStatChip(label: "Demand", value: analysis.demandLevel, color: .orange)
                }
            }
            
            // Pricing strategy
            CleanPricingStrategy(analysis: analysis)
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onAddToInventory) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Inventory")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(CleanButtonStyle())
                
                Button(action: onDirectList) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Create eBay Listing")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green)
                    )
                }
                .buttonStyle(CleanButtonStyle())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

struct CleanStatChip: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct CleanPricingStrategy: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pricing Strategy")
                .font(.system(size: 20, weight: .bold))
            
            HStack(spacing: 12) {
                CleanPriceCard(
                    title: "Quick Sale",
                    price: analysis.quickSalePrice,
                    subtitle: "Fast turnover",
                    color: .orange
                )
                
                CleanPriceCard(
                    title: "Recommended",
                    price: analysis.realisticPrice,
                    subtitle: "Best value",
                    color: .accentColor,
                    isHighlighted: true
                )
                
                CleanPriceCard(
                    title: "Premium",
                    price: analysis.maxProfitPrice,
                    subtitle: "Max profit",
                    color: .green
                )
            }
            
            if !analysis.soldListings.isEmpty {
                Text("Based on \(analysis.soldListings.count) recent sales")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.05))
        )
    }
}

struct CleanPriceCard: View {
    let title: String
    let price: Double
    let subtitle: String
    let color: Color
    let isHighlighted: Bool
    
    init(title: String, price: Double, subtitle: String, color: Color, isHighlighted: Bool = false) {
        self.title = title
        self.price = price
        self.subtitle = subtitle
        self.color = color
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isHighlighted ? .white : color)
            
            Text("$\(String(format: "%.0f", price))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isHighlighted ? .white : color)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? color : color.opacity(0.1))
        )
    }
}

// MARK: - Clean Button Style
struct CleanButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Clean Prospecting View
struct ProspectingView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var aiService: AIService
    
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var prospectAnalysis: ProspectAnalysis?
    @State private var showingBarcodeLookup = false
    @State private var scannedBarcode: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            Text("Prospecting")
                                .font(.system(size: 32, weight: .bold))
                            Spacer()
                        }
                        
                        Text("Get instant max buy prices")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if aiService.isAnalyzing {
                            CleanProgressCard(
                                progress: Double(aiService.currentStep) / Double(aiService.totalSteps),
                                message: aiService.analysisProgress,
                                onCancel: { /* Cancel logic */ }
                            )
                        }
                    }
                    
                    // Photo interface
                    if !capturedImages.isEmpty {
                        CleanPhotoGallery(images: $capturedImages)
                    } else {
                        ProspectPhotoPlaceholder {
                            showingCamera = true
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            CleanActionButton(icon: "camera.fill", title: "Camera", color: .purple, action: { showingCamera = true })
                            CleanActionButton(icon: "photo.on.rectangle", title: "Photos", color: .green, action: { showingPhotoLibrary = true })
                            CleanActionButton(icon: "barcode.viewfinder", title: "Scan", color: .orange, action: { showingBarcodeLookup = true })
                        }
                        
                        if !capturedImages.isEmpty {
                            Button(action: analyzeForProspecting) {
                                HStack(spacing: 8) {
                                    Image(systemName: "scope")
                                    Text("Get Max Buy Price")
                                }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.purple)
                                )
                            }
                            .disabled(aiService.isAnalyzing || !Configuration.isFullyConfigured)
                            .buttonStyle(CleanButtonStyle())
                        }
                    }
                    
                    // Results
                    if let analysis = prospectAnalysis {
                        CleanProspectResult(analysis: analysis)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { photos in
                let optimized = photos.compactMap { optimizeImage($0) }
                capturedImages.append(contentsOf: optimized)
                prospectAnalysis = nil
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPicker { photos in
                let optimized = photos.compactMap { optimizeImage($0) }
                capturedImages.append(contentsOf: optimized)
                prospectAnalysis = nil
            }
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            BarcodeScannerView(scannedCode: $scannedBarcode)
                .onDisappear {
                    if let barcode = scannedBarcode {
                        lookupBarcode(barcode)
                    }
                }
        }
    }
    
    private func optimizeImage(_ image: UIImage) -> UIImage? {
        let maxSize: CGFloat = 1024
        let size = image.size
        
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let optimizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return optimizedImage
    }
    
    private func analyzeForProspecting() {
        guard !capturedImages.isEmpty else { return }
        
        aiService.analyzeForProspecting(images: capturedImages, category: "All") { analysis in
            DispatchQueue.main.async {
                self.prospectAnalysis = analysis
            }
        }
    }
    
    private func lookupBarcode(_ barcode: String) {
        aiService.lookupBarcodeForProspecting(barcode) { analysis in
            DispatchQueue.main.async {
                self.prospectAnalysis = analysis
            }
        }
    }
}

struct ProspectPhotoPlaceholder: View {
    let onTakePhotos: () -> Void
    
    var body: some View {
        Button(action: onTakePhotos) {
            VStack(spacing: 20) {
                Image(systemName: "scope")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(.purple)
                
                VStack(spacing: 8) {
                    Text("Prospect Items")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("Get instant max buy prices")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .foregroundColor(.purple.opacity(0.3))
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.03))
            )
        }
        .buttonStyle(CleanButtonStyle())
    }
}

struct CleanProspectResult: View {
    let analysis: ProspectAnalysis
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with recommendation
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(analysis.itemName)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(2)
                        
                        if !analysis.brand.isEmpty {
                            Text(analysis.brand)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text(analysis.recommendation.emoji)
                            .font(.system(size: 32))
                        Text(analysis.recommendation.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(analysis.recommendation.color)
                    }
                }
            }
            
            // Buy pricing strategy
            CleanBuyPricingStrategy(analysis: analysis)
            
            // Market data if available
            if !analysis.recentSales.isEmpty {
                CleanRecentSales(sales: Array(analysis.recentSales.prefix(3)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

struct CleanBuyPricingStrategy: View {
    let analysis: ProspectAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Buy Price Strategy")
                .font(.system(size: 20, weight: .bold))
            
            HStack(spacing: 12) {
                CleanBuyPriceCard(
                    title: "Max Pay",
                    price: analysis.maxBuyPrice,
                    subtitle: "Don't exceed",
                    color: .red,
                    isHighlighted: true
                )
                
                CleanBuyPriceCard(
                    title: "Target",
                    price: analysis.targetBuyPrice,
                    subtitle: "Good deal",
                    color: .orange
                )
                
                CleanBuyPriceCard(
                    title: "Sell For",
                    price: analysis.estimatedSellPrice,
                    subtitle: "Market price",
                    color: .green
                )
            }
            
            // Profit summary
            if analysis.potentialProfit > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Potential Profit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", analysis.potentialProfit))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Expected ROI")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.0f", analysis.expectedROI))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(getROIColor(analysis.expectedROI))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.05))
        )
    }
    
    private func getROIColor(_ roi: Double) -> Color {
        switch roi {
        case 100...: return .green
        case 50..<100: return .orange
        default: return .red
        }
    }
}

struct CleanBuyPriceCard: View {
    let title: String
    let price: Double
    let subtitle: String
    let color: Color
    let isHighlighted: Bool
    
    init(title: String, price: Double, subtitle: String, color: Color, isHighlighted: Bool = false) {
        self.title = title
        self.price = price
        self.subtitle = subtitle
        self.color = color
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isHighlighted ? .white : color)
            
            Text("$\(String(format: "%.2f", price))")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isHighlighted ? .white : color)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? color : color.opacity(0.1))
        )
    }
}

struct CleanRecentSales: View {
    let sales: [RecentSale]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sales")
                .font(.system(size: 20, weight: .bold))
            
            VStack(spacing: 8) {
                ForEach(sales, id: \.title) { sale in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sale.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            
                            if !sale.condition.isEmpty {
                                Text(sale.condition)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(String(format: "%.0f", sale.price))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                            
                            Text(formatSaleDate(sale.date))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
        )
    }
    
    private func formatSaleDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
