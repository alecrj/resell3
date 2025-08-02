import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

// MARK: - Focused Business Content View
struct ContentView: View {
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var aiService = AIService()
    @StateObject private var googleSheetsService = GoogleSheetsService()
    @StateObject private var ebayListingService = EbayListingService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Business Header
            BusinessHeader()
            
            // Main Business Content
            BusinessTabView()
                .environmentObject(inventoryManager)
                .environmentObject(aiService)
                .environmentObject(googleSheetsService)
                .environmentObject(ebayListingService)
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

// MARK: - Business Header Design
struct BusinessHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top section with logo and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ResellAI")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                    
                    Text("Ultimate Reselling Business Tool")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
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
                        
                        // Progress indicator
                        if aiService.isAnalyzing {
                            BusinessProgressCard(
                                progress: Double(aiService.currentStep) / Double(aiService.totalSteps),
                                message: aiService.analysisProgress,
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
                    
                    // Results
                    if let result = analysisResult {
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

// MARK: - Business UI Components

struct BusinessWarningBanner: View {
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

struct BusinessProgressCard: View {
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

struct BusinessPhotoGallery: View {
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

struct BusinessPhotoPlaceholder: View {
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
        .buttonStyle(ScaleButtonStyle())
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
                    color: .accentColor,
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

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
