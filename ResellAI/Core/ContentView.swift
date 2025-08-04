//
//  ContentView.swift
//  ResellAI
//
//  Final Fixed ContentView with Correct AIService Reference
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    var body: some View {
        BusinessTabView()
            .environmentObject(InventoryManager())
            .environmentObject(WorkingOpenAIService()) // Use explicit service name
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
    @EnvironmentObject var aiService: WorkingOpenAIService // Use explicit type
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
    @State private var showingAnalysisSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BusinessHeader()
                
                if capturedImages.isEmpty {
                    EmptyStateView()
                } else {
                    PhotoGridView(images: $capturedImages)
                }
                
                BusinessActionButtons(
                    hasPhotos: !capturedImages.isEmpty,
                    isAnalyzing: aiService.isAnalyzing,
                    isConfigured: Configuration.isFullyConfigured,
                    onCamera: { showingCamera = true },
                    onLibrary: { showingPhotoLibrary = true },
                    onBarcode: { showingBarcodeLookup = true },
                    onAnalyze: analyzePhotos,
                    onReset: resetAll
                )
                
                if let result = analysisResult {
                    AnalysisResultCard(
                        result: result,
                        onSaveToInventory: { saveToInventory(result) },
                        onListDirectly: { showingDirectListing = true }
                    )
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingCamera) {
            CameraView { images in
                capturedImages.append(contentsOf: images)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPickerView { images in
                capturedImages.append(contentsOf: images)
            }
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            BarcodeScannerView { barcode in
                scannedBarcode = barcode
                lookupBarcode(barcode)
            }
        }
        .sheet(isPresented: $showingItemForm) {
            if let result = analysisResult {
                ItemFormView(
                    analysis: result,
                    onSave: { item in
                        _ = inventoryManager.addItem(item)
                        showingItemForm = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingDirectListing) {
            if let result = analysisResult {
                DirectListingView(
                    analysis: result,
                    images: capturedImages,
                    onComplete: { success in
                        showingDirectListing = false
                        if success {
                            resetAll()
                        }
                    }
                )
            }
        }
        .onAppear {
            Configuration.validateConfiguration()
        }
    }
    
    private func analyzePhotos() {
        guard !capturedImages.isEmpty else { return }
        
        aiService.analyzeItem(images: capturedImages) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
            }
        }
    }
    
    private func lookupBarcode(_ barcode: String) {
        print("Looking up barcode: \(barcode)")
    }
    
    private func saveToInventory(_ result: AnalysisResult) {
        // Use the simplified constructor
        let item = InventoryItem(from: result, notes: "Added from photo analysis")
        _ = inventoryManager.addItem(item)
        showingItemForm = true
    }
    
    private func resetAll() {
        capturedImages.removeAll()
        analysisResult = nil
        scannedBarcode = nil
    }
}

// MARK: - Direct Listing View (Complete Implementation)
struct DirectListingView: View {
    let analysis: AnalysisResult
    let images: [UIImage]
    let onComplete: (Bool) -> Void
    
    @EnvironmentObject var ebayListingService: EbayListingService
    @State private var isListing = false
    @State private var listingProgress = 0.0
    @State private var currentStep = ""
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isListing {
                    listingProgressView
                } else if let error = error {
                    errorView(error)
                } else {
                    listingPreview
                }
            }
            .padding()
            .navigationTitle("List on eBay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onComplete(false) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("List Now") { startListing() }
                        .disabled(isListing)
                }
            }
        }
    }
    
    private var listingPreview: some View {
        VStack(spacing: 20) {
            Text("Ready to List")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Product:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(analysis.productName)
                }
                
                HStack {
                    Text("Brand:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(analysis.brand)
                }
                
                HStack {
                    Text("Condition:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(analysis.condition.rawValue)
                }
                
                HStack {
                    Text("Price:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(String(format: "%.2f", analysis.suggestedPrice))")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Text("This will create a listing on your connected eBay account.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var listingProgressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: listingProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(currentStep)
                .font(.headline)
            
            Text("Please wait...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Listing Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(errorMessage)
                .font(.body)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                error = nil
                startListing()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func startListing() {
        isListing = true
        error = nil
        
        let item = InventoryItem(from: analysis)
        
        Task {
            await ebayListingService.createListing(
                item: item,
                analysisResult: analysis,
                images: images
            )
            
            await MainActor.run {
                isListing = false
                if let listingError = ebayListingService.error {
                    error = listingError
                } else if ebayListingService.listingResult?.success == true {
                    onComplete(true)
                } else {
                    error = "Listing failed for unknown reason"
                }
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.blue)
                
                Text("Ready to Resell")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Take photos of items and let AI handle the rest")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Photo Grid View
struct PhotoGridView: View {
    @Binding var images: [UIImage]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(images.count) Photos")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
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
        .padding(.horizontal, 20)
    }
}

// MARK: - Business Action Buttons
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
            HStack(spacing: 12) {
                BusinessActionButton(
                    icon: "camera.fill",
                    title: "Camera",
                    color: .blue,
                    action: onCamera
                )
                
                BusinessActionButton(
                    icon: "photo.on.rectangle.angled",
                    title: "Library",
                    color: .green,
                    action: onLibrary
                )
                
                BusinessActionButton(
                    icon: "barcode.viewfinder",
                    title: "Barcode",
                    color: .orange,
                    action: onBarcode
                )
            }
            
            VStack(spacing: 12) {
                Button(action: onAnalyze) {
                    HStack(spacing: 8) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text(isAnalyzing ? "Analyzing..." : "Analyze Items")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(hasPhotos && isConfigured ?
                                Color.accentColor : Color.gray)
                    )
                }
                .disabled(isAnalyzing || !isConfigured || !hasPhotos)
                .buttonStyle(ScaleButtonStyle())
                
                if !isAnalyzing && hasPhotos {
                    Button("Start Over", action: onReset)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Business Action Button
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

// MARK: - Photo Library Picker View
struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onImagesSelected: ([UIImage]) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 8
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPickerView
        
        init(_ parent: PhotoLibraryPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            let group = DispatchGroup()
            var images: [UIImage] = []
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.parent.onImagesSelected(images)
            }
        }
    }
}

// MARK: - Analysis Result Card
struct AnalysisResultCard: View {
    let result: AnalysisResult
    let onSaveToInventory: () -> Void
    let onListDirectly: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Analysis Complete")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text(result.productName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(result.brand) • \(result.condition.rawValue)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("$\(String(format: "%.0f", result.suggestedPrice))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onSaveToInventory) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Save to Inventory")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: onListDirectly) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("List on eBay")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
