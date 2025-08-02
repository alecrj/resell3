import SwiftUI
import Foundation

// MARK: - Apple-Style Item Form View
struct ItemFormView: View {
    let analysis: AnalysisResult
    let onSave: (InventoryItem) -> Void
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var condition: String = ""
    @State private var purchasePrice: Double = 0
    @State private var suggestedPrice: Double = 0
    @State private var source: String = "Thrift Store"
    @State private var notes: String = ""
    @State private var size: String = ""
    @State private var colorway: String = ""
    @State private var storageLocation: String = ""
    
    let sources = ["Thrift Store", "Goodwill Bins", "Estate Sale", "Yard Sale", "Facebook Marketplace", "OfferUp", "Auction", "Other"]
    
    var estimatedProfit: Double {
        guard purchasePrice > 0 && suggestedPrice > 0 else { return 0 }
        let fees = suggestedPrice * 0.1325 + 8.50 + 0.30
        return suggestedPrice - purchasePrice - fees
    }
    
    var estimatedROI: Double {
        guard purchasePrice > 0 && estimatedProfit > 0 else { return 0 }
        return (estimatedProfit / purchasePrice) * 100
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Apple-style header
                    VStack(spacing: 8) {
                        Text("Add to Inventory")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Complete item details")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Photos section
                    if !analysis.images.isEmpty {
                        ApplePhotosPreview(images: analysis.images)
                    }
                    
                    // Form sections
                    VStack(spacing: 16) {
                        AppleFormSection(title: "Product Details") {
                            VStack(spacing: 16) {
                                AppleTextField(title: "Item Name", text: $name)
                                AppleTextField(title: "Brand", text: $brand)
                                AppleTextField(title: "Size", text: $size)
                                AppleTextField(title: "Color/Style", text: $colorway)
                                
                                AppleConditionPicker(selection: $condition)
                            }
                        }
                        
                        AppleFormSection(title: "Pricing") {
                            VStack(spacing: 16) {
                                ApplePriceField(title: "Purchase Price", value: $purchasePrice)
                                ApplePriceField(title: "Suggested Price", value: $suggestedPrice)
                                
                                if purchasePrice > 0 && suggestedPrice > 0 {
                                    AppleProfitDisplay(
                                        profit: estimatedProfit,
                                        roi: estimatedROI
                                    )
                                }
                            }
                        }
                        
                        AppleFormSection(title: "Source & Storage") {
                            VStack(spacing: 16) {
                                AppleSourcePicker(selection: $source, sources: sources)
                                AppleTextField(title: "Storage Location", text: $storageLocation)
                            }
                        }
                        
                        AppleFormSection(title: "Notes") {
                            AppleTextEditor(text: $notes, placeholder: "Additional notes...")
                        }
                        
                        AppleFormSection(title: "AI Analysis") {
                            AppleAnalysisSummary(analysis: analysis)
                        }
                    }
                    
                    // Save button
                    Button(action: saveItem) {
                        Text("Add to Inventory")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(name.isEmpty || purchasePrice <= 0 ? Color.gray : Color.blue)
                            )
                    }
                    .disabled(name.isEmpty || purchasePrice <= 0)
                    .buttonStyle(ScaleButtonStyle())
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            loadFromAnalysis()
        }
    }
    
    private func loadFromAnalysis() {
        name = analysis.itemName
        brand = analysis.brand
        condition = analysis.actualCondition
        suggestedPrice = analysis.realisticPrice
        size = analysis.identificationResult.size
        colorway = analysis.identificationResult.colorway
    }
    
    private func saveItem() {
        let imageData = analysis.images.first?.jpegData(compressionQuality: 0.8)
        let additionalImageData = analysis.images.dropFirst().compactMap { $0.jpegData(compressionQuality: 0.7) }
        
        let newItem = InventoryItem(
            itemNumber: inventoryManager.nextItemNumber,
            name: name,
            category: analysis.category,
            purchasePrice: purchasePrice,
            suggestedPrice: suggestedPrice,
            source: source,
            condition: condition,
            title: analysis.ebayTitle,
            description: analysis.description,
            keywords: analysis.keywords,
            status: .analyzed,
            dateAdded: Date(),
            imageData: imageData,
            additionalImageData: additionalImageData.isEmpty ? nil : additionalImageData,
            aiConfidence: analysis.confidence.overall,
            competitorCount: analysis.competitorCount,
            demandLevel: analysis.demandLevel,
            brand: brand,
            exactModel: analysis.itemName,
            styleCode: analysis.identificationResult.styleCode,
            size: size,
            colorway: colorway,
            storageLocation: storageLocation,
            ebayCondition: analysis.ebayCondition
        )
        
        onSave(newItem)
    }
}

// MARK: - Apple Form Components

struct ApplePhotosPreview: View {
    let images: [UIImage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Photos")
                .font(.system(size: 20, weight: .semibold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<images.count, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                            .clipped()
                    }
                }
                .padding(.horizontal, 4)
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

struct AppleFormSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct AppleTextField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            TextField("Enter \(title.lowercased())", text: $text)
                .font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

struct ApplePriceField: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                Text("$")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("0.00", value: $value, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct AppleConditionPicker: View {
    @Binding var selection: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Condition")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Picker("Condition", selection: $selection) {
                ForEach(EbayCondition.allCases, id: \.self) { condition in
                    Text(condition.rawValue).tag(condition.rawValue)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct AppleSourcePicker: View {
    @Binding var selection: String
    let sources: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Picker("Source", selection: $selection) {
                ForEach(sources, id: \.self) { source in
                    Text(source).tag(source)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct AppleTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct AppleProfitDisplay: View {
    let profit: Double
    let roi: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Est. Profit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", profit))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(profit > 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. ROI")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.0f", roi))%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(getROIColor(roi))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
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

struct AppleAnalysisSummary: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.0f", analysis.confidence.overall * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(getConfidenceColor(analysis.confidence.overall))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Market Data")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(analysis.soldListings.count) sales")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(analysis.category)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Market Price")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.0f", analysis.realisticPrice))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
        )
    }
    
    private func getConfidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

// MARK: - Apple-Style Direct eBay Listing View
struct DirectEbayListingView: View {
    let analysis: AnalysisResult
    @EnvironmentObject var ebayListingService: EbayListingService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var generatedListing = ""
    @State private var isGenerating = false
    @State private var listingURL: String?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Apple-style header
                    VStack(spacing: 8) {
                        Text("Create eBay Listing")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Professional listing generation")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Analysis summary
                    AppleAnalysisSummaryCard(analysis: analysis)
                    
                    // Generated listing
                    if generatedListing.isEmpty {
                        Button(action: generateListing) {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Generating...")
                                } else {
                                    Image(systemName: "doc.text.fill")
                                    Text("Generate Professional Listing")
                                }
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green)
                            )
                        }
                        .disabled(isGenerating)
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        AppleGeneratedListingCard(
                            listing: generatedListing,
                            listingURL: listingURL,
                            onShare: { showingShareSheet = true },
                            onCopy: copyToClipboard
                        )
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generatedListing])
        }
    }
    
    private func generateListing() {
        isGenerating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isGenerating = false
            generatedListing = createOptimizedListing()
        }
    }
    
    private func createOptimizedListing() -> String {
        return """
        \(analysis.ebayTitle)
        
        CONDITION: \(analysis.actualCondition)
        \(analysis.ebayCondition.description)
        
        DETAILS:
        • Brand: \(analysis.brand)
        • Category: \(analysis.category)
        • Model: \(analysis.itemName)
        • Size: \(analysis.identificationResult.size)
        • Style: \(analysis.identificationResult.colorway)
        • Code: \(analysis.identificationResult.styleCode)
        • Verified Authentic
        
        MARKET INSIGHTS:
        • Based on \(analysis.soldListings.count) recent sales
        • Average price: $\(String(format: "%.2f", analysis.averagePrice))
        • \(analysis.confidence.overall > 0.8 ? "High" : "Good") confidence analysis
        
        SHIPPING:
        • Fast shipping with tracking
        • Carefully packaged
        • 30-day returns
        
        WHY BUY FROM US:
        ✓ AI-verified authentic items
        ✓ Professional condition assessment
        ✓ Fast shipping
        ✓ Excellent service
        
        Keywords: \(analysis.keywords.joined(separator: " "))
        
        Starting: $\(String(format: "%.2f", analysis.quickSalePrice))
        Buy Now: $\(String(format: "%.2f", analysis.realisticPrice))
        """
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = generatedListing
    }
}

// MARK: - Apple Analysis Summary Card
struct AppleAnalysisSummaryCard: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(spacing: 16) {
            if let firstImage = analysis.images.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 160)
                    .cornerRadius(12)
                    .clipped()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(analysis.itemName)
                            .font(.system(size: 20, weight: .bold))
                            .lineLimit(2)
                        
                        if !analysis.brand.isEmpty {
                            Text(analysis.brand)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(String(format: "%.0f", analysis.realisticPrice))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Market Price")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    AppleStatChip(label: "Condition", value: analysis.actualCondition, color: .blue)
                    AppleStatChip(label: "Sales", value: "\(analysis.soldListings.count)", color: .purple)
                    
                    Text("\(String(format: "%.0f", analysis.confidence.overall * 100))% confident")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if !analysis.soldListings.isEmpty {
                    Text("Based on \(analysis.soldListings.count) recent sales")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
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

// MARK: - Apple Generated Listing Card
struct AppleGeneratedListingCard: View {
    let listing: String
    let listingURL: String?
    let onShare: () -> Void
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Professional eBay Listing")
                .font(.system(size: 20, weight: .semibold))
            
            ScrollView {
                Text(listing)
                    .font(.system(size: 16, weight: .medium))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .frame(maxHeight: 300)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button("Share") {
                        onShare()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button("Copy") {
                        onCopy()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                    .buttonStyle(ScaleButtonStyle())
                }
                
                if let url = listingURL {
                    Button("View on eBay") {
                        if let ebayURL = URL(string: url) {
                            UIApplication.shared.open(ebayURL)
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange)
                    )
                    .buttonStyle(ScaleButtonStyle())
                }
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
