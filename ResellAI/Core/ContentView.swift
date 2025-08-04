//
//  ContentView.swift
//  ResellAI
//
//  Main app interface for the complete resell workflow
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var ebayService = EbayService()
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var selectedPrice: Double = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    
                    if !ebayService.isAuthenticated {
                        ebayAuthSection
                    } else {
                        mainWorkflowSection
                    }
                    
                    if let analysis = appState.currentAnalysis {
                        analysisResultsSection(analysis)
                    }
                    
                    if !appState.recentAnalyses.isEmpty {
                        recentAnalysesSection
                    }
                }
                .padding()
            }
            .navigationTitle("ResellAI")
            .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
                Button("OK") { appState.clearError() }
            } message: {
                Text(appState.errorMessage ?? "")
            }
            .sheet(isPresented: $showingPhotoPicker) {
                photoPickerSheet
            }
            .sheet(isPresented: $showingCamera) {
                CameraViewWrapper { image in
                    selectedImages.append(image)
                    showingCamera = false
                }
            }
        }
        .onAppear {
            Configuration.validateConfiguration()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Upload Photo → AI Analysis → eBay Listing")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if appState.isAnalyzing {
                ProgressView("Analyzing item...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - eBay Authentication
    
    private var ebayAuthSection: some View {
        VStack(spacing: 15) {
            Text("Connect to eBay")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Authenticate with eBay to search sold items and post listings automatically")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: authenticateWithEbay) {
                HStack {
                    Image(systemName: "link")
                    Text("Connect eBay Account")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Main Workflow
    
    private var mainWorkflowSection: some View {
        VStack(spacing: 20) {
            // Photo Upload Section
            VStack(spacing: 15) {
                Text("1. Upload Photos")
                    .font(.headline)
                
                if selectedImages.isEmpty {
                    Button(action: { showingPhotoPicker = true }) {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                            Text("Take or Select Photos")
                                .font(.headline)
                        }
                        .foregroundColor(.blue)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                    }
                } else {
                    photoPreviewSection
                }
                
                HStack(spacing: 15) {
                    Button("Camera") {
                        showingCamera = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Photo Library") {
                        showingPhotoPicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    if !selectedImages.isEmpty {
                        Button("Clear") {
                            selectedImages.removeAll()
                            selectedPhotos.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            }
            
            // Analysis Button
            if !selectedImages.isEmpty && !appState.isAnalyzing {
                Button(action: analyzeItem) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("2. Analyze Item & Get eBay Comps")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Photo Preview
    
    private var photoPreviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                        .overlay(
                            Button(action: { removeImage(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .offset(x: 8, y: -8),
                            alignment: .topTrailing
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Analysis Results
    
    private func analysisResultsSection(_ analysis: ItemAnalysis) -> some View {
        VStack(spacing: 20) {
            // Item Details
            VStack(alignment: .leading, spacing: 10) {
                Text("Analysis Results")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("Item:")
                        .fontWeight(.medium)
                    Text(analysis.title)
                }
                
                HStack {
                    Text("Brand:")
                        .fontWeight(.medium)
                    Text(analysis.brand)
                }
                
                HStack {
                    Text("Condition:")
                        .fontWeight(.medium)
                    Text(analysis.condition.rawValue)
                }
                
                HStack {
                    Text("Confidence:")
                        .fontWeight(.medium)
                    Text("\(Int(analysis.confidence * 100))%")
                        .foregroundColor(analysis.confidence > 0.8 ? .green : .orange)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Pricing Section
            pricingSection(analysis)
            
            // eBay Comps
            if !analysis.ebayComps.isEmpty {
                ebayCompsSection(analysis.ebayComps)
            }
            
            // Post to eBay Button
            postToEbayButton(analysis)
        }
    }
    
    // MARK: - Pricing Section
    
    private func pricingSection(_ analysis: ItemAnalysis) -> some View {
        VStack(spacing: 15) {
            Text("3. Choose Your Price")
                .font(.headline)
            
            VStack(spacing: 10) {
                pricingOption(
                    strategy: .quickSale,
                    price: analysis.quickSalePrice,
                    isSelected: selectedPrice == analysis.quickSalePrice
                )
                
                pricingOption(
                    strategy: .competitive,
                    price: analysis.suggestedPrice,
                    isSelected: selectedPrice == analysis.suggestedPrice
                )
                
                pricingOption(
                    strategy: .premium,
                    price: analysis.premiumPrice,
                    isSelected: selectedPrice == analysis.premiumPrice
                )
            }
        }
    }
    
    private func pricingOption(strategy: PricingStrategy, price: Double, isSelected: Bool) -> some View {
        Button(action: { selectedPrice = price }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(strategy.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(strategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$\(price, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - eBay Comps Section
    
    private func ebayCompsSection(_ comps: [EbayComp]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent eBay Sales (\(comps.count) found)")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(comps.prefix(5)) { comp in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comp.title)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(comp.condition)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDate(comp.soldDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("$\(comp.totalPrice, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Post to eBay Button
    
    private func postToEbayButton(_ analysis: ItemAnalysis) -> some View {
        VStack(spacing: 10) {
            if selectedPrice == 0 {
                Text("Select a price to continue")
                    .foregroundColor(.secondary)
            } else {
                Button(action: { postToEbay(analysis) }) {
                    HStack {
                        if appState.isPostingToEbay {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("4. Post to eBay - $\(selectedPrice, specifier: "%.2f")")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(appState.isPostingToEbay ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(appState.isPostingToEbay)
            }
        }
    }
    
    // MARK: - Recent Analyses
    
    private var recentAnalysesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Analyses")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(appState.recentAnalyses.prefix(3)) { analysis in
                    HStack {
                        Text(analysis.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("$\(analysis.suggestedPrice, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func authenticateWithEbay() {
        guard let authURL = ebayService.startOAuthFlow() else {
            appState.setError(.ebayAuthError("Failed to create auth URL"))
            return
        }
        
        UIApplication.shared.open(authURL)
    }
    
    private func analyzeItem() {
        guard !selectedImages.isEmpty else { return }
        
        Task {
            appState.isAnalyzing = true
            selectedPrice = 0
            
            do {
                let analysis = try await openAIService.analyzeItem(photos: selectedImages)
                appState.addAnalysis(analysis)
            } catch {
                appState.setError(error as? ResellAIError ?? .analysisError(error.localizedDescription))
            }
            
            appState.isAnalyzing = false
        }
    }
    
    private func postToEbay(_ analysis: ItemAnalysis) {
        guard selectedPrice > 0 else { return }
        
        Task {
            appState.isPostingToEbay = true
            
            do {
                let listing = EbayListing(from: analysis, price: selectedPrice)
                let listingID = try await ebayService.postListing(listing)
                
                // Success - could show success message or navigate to listing
                print("Successfully posted listing: \(listingID)")
                
            } catch {
                appState.setError(error as? ResellAIError ?? .ebayListingError(error.localizedDescription))
            }
            
            appState.isPostingToEbay = false
        }
    }
    
    private func removeImage(at index: Int) {
        selectedImages.remove(at: index)
        selectedPhotos.remove(at: index)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Photo Picker Extension

extension ContentView {
    private var photoPickerSheet: some View {
        PhotosPicker(
            selection: $selectedPhotos,
            maxSelectionCount: Configuration.maxPhotos,
            matching: .images
        ) {
            Text("Select Photos")
        }
        .onChange(of: selectedPhotos) { newPhotos in
            loadSelectedPhotos(newPhotos)
        }
    }
    
    private func loadSelectedPhotos(_ photos: [PhotosPickerItem]) {
        selectedImages.removeAll()
        
        for photo in photos {
            photo.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            selectedImages.append(image)
                        }
                    }
                case .failure(let error):
                    print("Error loading photo: \(error)")
                }
            }
        }
    }
}

// MARK: - Camera View Wrapper

struct CameraViewWrapper: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraViewWrapper
        
        init(_ parent: CameraViewWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ContentView()
}
