//
//  ContentView.swift
//  ResellAI
//
//  Fixed ContentView with Correct AIService Integration
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        BusinessTabView()
            .environmentObject(InventoryManager())
            .environmentObject(AIService())
            .environmentObject(GoogleSheetsService())
            .environmentObject(EbayListingService())
    }
}

// MARK: - Business Header
struct BusinessHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ResellAI")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
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

// MARK: - Business Tab View
struct BusinessTabView: View {
    var body: some View {
        TabView {
            BusinessAnalysisView()
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

// MARK: - Business Analysis View
struct BusinessAnalysisView: View {
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
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            Text("Item Analysis")
                                .font(.system(size: 32, weight: .bold))
                            Spacer()
                        }
                        
                        if !Configuration.isFullyConfigured {
                            BusinessWarningBanner(
                                message: "Some APIs need configuration",
                                actionText: "Check Settings",
                                onAction: { }
                            )
                        }
                        
                        // Progress indicator - FIXED
                        if aiService.isAnalyzing {
                            BusinessProgressCard(
                                progress: aiService.analysisProgress,
                                message: aiService.currentStep,
                                onCancel: { resetAnalysis() }
                            )
                        }
                    }
                    
                    // Photo section
                    if !capturedImages.isEmpty {
                        BusinessPhotoGallery(images: $capturedImages)
                    } else {
                        BusinessPhotoPlaceholder {
                            showingCamera = true
                        }
                    }
                    
                    // Action buttons
                    BusinessActionButtons(
                        hasPhotos: !capturedImages.isEmpty,
                        isAnalyzing: aiService.isAnalyzing,
                        isConfigured: Configuration.isFullyConfigured,
                        onCamera: { showingCamera = true },
                        onLibrary: { showingPhotoLibrary = true },
                        onBarcode: { showingBarcodeLookup = true },
                        onAnalyze: { analyzeItem() },
                        onReset: { resetAnalysis() }
                    )
                    
                    // Results - FIXED
                    if let result = aiService.analysisResult {
                        CleanAnalysisResultView(analysis: result) {
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
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { images in
                handleNewImages(images)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryView { images in
                handleNewImages(images)
            }
        }
        .sheet(isPresented: $showingItemForm) {
            if let result = aiService.analysisResult {
                ItemFormView(analysisResult: result) { item in
                    saveItem(item)
                }
            }
        }
        .sheet(isPresented: $showingDirectListing) {
            if let result = aiService.analysisResult {
                ListingView(
                    item: createInventoryItem(from: result),
                    analysisResult: result,
                    images: capturedImages
                )
            }
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            BarcodeScannerView { barcode in
                scannedBarcode = barcode
                analyzeBarcode(barcode)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleNewImages(_ images: [UIImage]) {
        let optimizedPhotos = images.compactMap { image in
            return optimizeImage(image)
        }
        capturedImages.append(contentsOf: optimizedPhotos)
        // Reset analysis result when new images are added
        aiService.analysisResult = nil
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
    
    // FIXED - Now uses async/await pattern
    private func analyzeItem() {
        guard !capturedImages.isEmpty else { return }
        
        Task {
            await aiService.analyzeItem(images: capturedImages)
        }
    }
    
    private func analyzeBarcode(_ barcode: String) {
        // For now, just analyze the images we have
        analyzeItem()
    }
    
    // FIXED - Proper method calls
    private func saveItem(_ item: InventoryItem) {
        inventoryManager.addItem(item)
        Task {
            await googleSheetsService.uploadItem(item)
        }
        showingItemForm = false
        resetAnalysis()
    }
    
    private func resetAnalysis() {
        capturedImages = []
        aiService.analysisResult = nil
        scannedBarcode = nil
    }
    
    private func createInventoryItem(from result: AnalysisResult) -> InventoryItem {
        return InventoryItem(
            itemNumber: inventoryManager.items.count + 1,
            name: result.productName,
            category: result.category,
            purchasePrice: 0.0,
            suggestedPrice: result.estimatedValue,
            source: "Analysis",
            condition: result.condition.rawValue,
            title: result.suggestedTitle,
            description: result.description,
            keywords: result.suggestedKeywords,
            status: .analyzed,
            dateAdded: Date(),
            brand: result.brand,
            ebayCondition: result.condition
        )
    }
}

// MARK: - Business UI Components

struct BusinessWarningBanner: View {
    let message: String
    let actionText: String
    let onAction: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(actionText, action: onAction)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct BusinessProgressCard: View {
    let progress: Double
    let message: String
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Analyzing Item")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct BusinessPhotoPlaceholder: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("Take Photos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Tap to capture photos of your item")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct BusinessPhotoGallery: View {
    @Binding var images: [UIImage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos (\(images.count))")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Clear All") {
                    images.removeAll()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: images[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(12)
                            
                            Button {
                                images.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .offset(x: -4, y: 4)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct BusinessActionButtons: View {
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
                BusinessActionButton(
                    icon: "camera.fill",
                    title: "Camera",
                    color: .blue,
                    action: onCamera
                )
                
                BusinessActionButton(
                    icon: "photo.on.rectangle",
                    title: "Photos",
                    color: .green,
                    action: onLibrary
                )
                
                BusinessActionButton(
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
                .buttonStyle(ScaleButtonStyle())
                
                // Reset button
                if !isAnalyzing {
                    Button("Start Over", action: onReset)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}

struct BusinessActionButton: View {
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
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
