//
//  ListingView.swift
//  ResellAI
//
//  Created by Alec on 8/3/25.
//


//
//  ListingView.swift
//  ResellAI
//
//  Complete Photo to eBay Listing Flow
//

import SwiftUI
import PhotosUI

struct ListingView: View {
    @StateObject private var aiService = AIService()
    @StateObject private var ebayListingService = EbayListingService()
    @StateObject private var ebayAuthManager = EbayAuthManager()
    
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var analysisResult: AnalysisResult?
    @State private var showingResults = false
    @State private var listingResult: EbayListingResult?
    @State private var showingListingResult = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Snap, Analyze, List")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Take photos and ResellAI does the rest")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                    
                    // Status Cards
                    StatusCardsView(
                        aiService: aiService,
                        ebayAuthManager: ebayAuthManager,
                        ebayListingService: ebayListingService
                    )
                    
                    // Photo Selection
                    PhotoSelectionView(
                        selectedImages: $selectedImages,
                        showingImagePicker: $showingImagePicker
                    )
                    
                    // Analysis Section
                    if !selectedImages.isEmpty {
                        AnalysisSection(
                            aiService: aiService,
                            selectedImages: selectedImages,
                            analysisResult: $analysisResult,
                            showingResults: $showingResults,
                            isProcessing: $isProcessing
                        )
                    }
                    
                    // eBay Authentication
                    EbayAuthSection(ebayAuthManager: ebayAuthManager)
                    
                    // Listing Section
                    if let analysis = analysisResult,
                       ebayAuthManager.isAuthenticated {
                        ListingSection(
                            ebayListingService: ebayListingService,
                            analysisResult: analysis,
                            selectedImages: selectedImages,
                            listingResult: $listingResult,
                            showingListingResult: $showingListingResult
                        )
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("ResellAI")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImages: $selectedImages)
            }
            .sheet(isPresented: $showingResults) {
                if let result = analysisResult {
                    AnalysisResultView(result: result)
                }
            }
            .sheet(isPresented: $showingListingResult) {
                if let result = listingResult {
                    ListingResultView(result: result)
                }
            }
        }
    }
}

// MARK: - Status Cards View
struct StatusCardsView: View {
    let aiService: AIService
    let ebayAuthManager: EbayAuthManager
    let ebayListingService: EbayListingService
    
    var body: some View {
        VStack(spacing: 12) {
            // AI Service Status
            StatusCard(
                title: "AI Analysis",
                status: aiService.isConfigured ? "Ready" : "Not Configured",
                icon: "brain.head.profile",
                color: aiService.isConfigured ? .green : .red
            )
            
            // eBay Auth Status
            StatusCard(
                title: "eBay Connection",
                status: ebayAuthManager.authenticationStatus,
                icon: "link",
                color: ebayAuthManager.isAuthenticated ? .green : .orange
            )
            
            // Configuration Status
            StatusCard(
                title: "System Status",
                status: Configuration.configurationStatus,
                icon: "gear",
                color: Configuration.isFullyConfigured ? .green : .red
            )
        }
    }
}

struct StatusCard: View {
    let title: String
    let status: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Photo Selection View
struct PhotoSelectionView: View {
    @Binding var selectedImages: [UIImage]
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Photos")
                    .font(.headline)
                Spacer()
                Text("\(selectedImages.count)/8")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if selectedImages.isEmpty {
                Button(action: { showingImagePicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                        Text("Take Photos")
                            .font(.headline)
                        Text("Capture clear photos of your item")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 5, y: -5)
                            }
                        }
                        
                        if selectedImages.count < 8 {
                            Button(action: { showingImagePicker = true }) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                    Text("Add")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .frame(width: 80, height: 80)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Analysis Section
struct AnalysisSection: View {
    let aiService: AIService
    let selectedImages: [UIImage]
    @Binding var analysisResult: AnalysisResult?
    @Binding var showingResults: Bool
    @Binding var isProcessing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("AI Analysis")
                    .font(.headline)
                Spacer()
                if let result = analysisResult {
                    Button("View Details") {
                        showingResults = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isProcessing {
                ProgressView(aiService.analysisProgress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let result = analysisResult {
                AnalysisPreview(result: result)
            } else {
                Button(action: startAnalysis) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Analyze Item")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(aiService.isConfigured ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!aiService.isConfigured)
            }
        }
    }
    
    private func startAnalysis() {
        isProcessing = true
        aiService.analyzeImages(selectedImages) { result in
            analysisResult = result
            isProcessing = false
        }
    }
}

struct AnalysisPreview: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(result.identificationResult.productName)
                        .font(.headline)
                    Text(result.brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("$\(result.realisticPrice, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Suggested Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label(result.ebayCondition.description, systemImage: "checkmark.circle")
                    .font(.caption)
                Spacer()
                Label("\(Int(result.roi.roiPercentage))% ROI", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(result.roi.isGoodDeal ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - eBay Auth Section
struct EbayAuthSection: View {
    @ObservedObject var ebayAuthManager: EbayAuthManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("eBay Connection")
                    .font(.headline)
                Spacer()
                if ebayAuthManager.isAuthenticated {
                    Button("Sign Out") {
                        ebayAuthManager.signOut()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            if ebayAuthManager.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(ebayAuthManager.authenticationStatus)
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    if ebayAuthManager.isAuthenticating {
                        ProgressView("Connecting to eBay...")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    } else {
                        Button(action: {
                            ebayAuthManager.signInWithEbay { success in
                                if !success {
                                    print("eBay sign-in failed")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect eBay Account")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(ebayAuthManager.validateCredentials() ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!ebayAuthManager.validateCredentials())
                        
                        if let error = ebayAuthManager.authError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Listing Section
struct ListingSection: View {
    @ObservedObject var ebayListingService: EbayListingService
    let analysisResult: AnalysisResult
    let selectedImages: [UIImage]
    @Binding var listingResult: EbayListingResult?
    @Binding var showingListingResult: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Create eBay Listing")
                    .font(.headline)
                Spacer()
            }
            
            if ebayListingService.isListing {
                ProgressView(ebayListingService.listingProgress)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                Button(action: createListing) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("List on eBay")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                if let lastResult = ebayListingService.listingResults.last {
                    ListingStatusView(result: lastResult) {
                        showingListingResult = true
                        listingResult = lastResult
                    }
                }
            }
        }
    }
    
    private func createListing() {
        let item = InventoryItem(
            name: analysisResult.identificationResult.productName,
            photos: selectedImages
        )
        
        ebayListingService.createListing(
            item: item,
            analysis: analysisResult
        ) { result in
            listingResult = result
            showingListingResult = true
        }
    }
}

struct ListingStatusView: View {
    let result: EbayListingResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.success ? "Listed Successfully" : "Listing Failed")
                    .font(.subheadline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImages.append(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Result Views
struct AnalysisResultView: View {
    let result: AnalysisResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Product Details")
                            .font(.headline)
                        
                        Text(result.identificationResult.productName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Brand: \(result.brand)")
                        Text("Size: \(result.identificationResult.size)")
                        Text("Color: \(result.identificationResult.colorway)")
                        Text("Condition: \(result.ebayCondition.description)")
                    }
                    
                    Divider()
                    
                    // Pricing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pricing Analysis")
                            .font(.headline)
                        
                        HStack {
                            Text("Suggested Price:")
                            Spacer()
                            Text("$\(result.realisticPrice, specifier: "%.2f")")
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Quick Sale:")
                            Spacer()
                            Text("$\(result.quickSalePrice, specifier: "%.2f")")
                        }
                        
                        HStack {
                            Text("Max Profit:")
                            Spacer()
                            Text("$\(result.maxProfitPrice, specifier: "%.2f")")
                        }
                        
                        HStack {
                            Text("ROI:")
                            Spacer()
                            Text("\(Int(result.roi.roiPercentage))%")
                                .foregroundColor(result.roi.isGoodDeal ? .green : .orange)
                                .fontWeight(.bold)
                        }
                    }
                    
                    Divider()
                    
                    // Selling Points
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Selling Points")
                            .font(.headline)
                        
                        ForEach(result.sellingPoints, id: \.self) { point in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(point)
                                Spacer()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ListingResultView: View {
    let result: EbayListingResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(result.success ? .green : .red)
                
                VStack(spacing: 16) {
                    Text(result.success ? "Listing Created!" : "Listing Failed")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if result.success {
                        Text("Your item has been successfully listed on eBay")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        if let listingURL = result.listingURL {
                            Button("View on eBay") {
                                if let url = URL(string: listingURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        if let listingId = result.listingId {
                            Text("Listing ID: \(listingId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(result.error ?? "Unknown error occurred")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Listing Result")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Preview
struct ListingView_Previews: PreviewProvider {
    static var previews: some View {
        ListingView()
    }
}