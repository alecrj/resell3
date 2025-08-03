//
//  EbayCompDemoView.swift
//  ResellAI
//
//  Demo View to Test Real eBay Comp Lookup - Fixed
//

import SwiftUI

// MARK: - eBay Comp Demo View
struct EbayCompDemoView: View {
    @StateObject private var ebayAPIService = EbayAPIService()
    @State private var searchKeywords = ""
    @State private var soldComps: [EbaySoldListing] = []
    @State private var compAnalysis: CompAnalysis?
    @State private var isSearching = false
    @State private var searchMessage = ""
    
    // Pre-defined test searches
    let testSearches = [
        ["Nike", "Air Force 1"],
        ["Guess", "Los Angeles", "shirt"],
        ["Jordan", "1", "bred"],
        ["Apple", "iPhone", "13"],
        ["Adidas", "Yeezy", "350"]
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("eBay Comp Lookup Test")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Real eBay API Integration")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Status indicator
                        HStack {
                            Circle()
                                .fill(ebayAPIService.isAuthenticated ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(ebayAPIService.authStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Search Interface
                    VStack(spacing: 16) {
                        Text("Search eBay Sold Comps")
                            .font(.headline)
                        
                        // Manual search
                        HStack {
                            TextField("Enter keywords (e.g., Nike Air Force 1)", text: $searchKeywords)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Search") {
                                searchManualKeywords()
                            }
                            .disabled(searchKeywords.isEmpty || isSearching)
                        }
                        
                        // Quick test buttons
                        Text("Or try these test searches:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(0..<testSearches.count, id: \.self) { index in
                                Button(testSearches[index].joined(separator: " ")) {
                                    searchTestKeywords(testSearches[index])
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                                .disabled(isSearching)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Search Status
                    if isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching eBay...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    if !searchMessage.isEmpty {
                        Text(searchMessage)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                    }
                    
                    // Analysis Results
                    if let analysis = compAnalysis {
                        CompAnalysisCard(analysis: analysis)
                    }
                    
                    // Sold Comps List
                    if !soldComps.isEmpty {
                        SoldCompsListView(soldComps: soldComps)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Search Functions
    private func searchManualKeywords() {
        let keywords = searchKeywords.components(separatedBy: " ").filter { !$0.isEmpty }
        performSearch(keywords: keywords)
    }
    
    private func searchTestKeywords(_ keywords: [String]) {
        searchKeywords = keywords.joined(separator: " ")
        performSearch(keywords: keywords)
    }
    
    private func performSearch(keywords: [String]) {
        guard !keywords.isEmpty else { return }
        
        isSearching = true
        searchMessage = "Searching for: \(keywords.joined(separator: " "))"
        soldComps = []
        compAnalysis = nil
        
        print("🔍 Demo search starting for: \(keywords)")
        
        ebayAPIService.getSoldComps(keywords: keywords) { results in
            DispatchQueue.main.async {
                self.isSearching = false
                self.soldComps = results
                
                if results.isEmpty {
                    self.searchMessage = "No sold comps found for '\(keywords.joined(separator: " "))'"
                } else {
                    self.searchMessage = "Found \(results.count) sold comps from last 30 days"
                    self.compAnalysis = self.ebayAPIService.analyzeComps(results)
                    
                    print("✅ Demo search complete:")
                    print("  • Found: \(results.count) sold items")
                    print("  • Average Price: $\(String(format: "%.2f", self.compAnalysis?.averagePrice ?? 0))")
                    print("  • Price Range: $\(String(format: "%.2f", self.compAnalysis?.lowPrice ?? 0)) - $\(String(format: "%.2f", self.compAnalysis?.highPrice ?? 0))")
                }
            }
        }
    }
}

// MARK: - Comp Analysis Card
struct CompAnalysisCard: View {
    let analysis: CompAnalysis
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Market Analysis")
                .font(.headline)
                .fontWeight(.bold)
            
            // Key metrics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(title: "Average Price", value: "$\(String(format: "%.2f", analysis.averagePrice))", color: .green)
                MetricCard(title: "Median Price", value: "$\(String(format: "%.2f", analysis.medianPrice))", color: .blue)
                MetricCard(title: "Price Range", value: "$\(String(format: "%.0f", analysis.lowPrice))-\(String(format: "%.0f", analysis.highPrice))", color: .orange)
                MetricCard(title: "Total Sales", value: "\(analysis.totalSales)", color: .purple)
            }
            
            // Additional insights
            VStack(spacing: 8) {
                HStack {
                    Text("Market Confidence:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.1f", analysis.marketConfidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Demand Level:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(analysis.demandLevel)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(getDemandColor(analysis.demandLevel))
                }
                
                HStack {
                    Text("Avg Days to Sell:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(analysis.averageDaysToSell)) days")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func getDemandColor(_ demand: String) -> Color {
        switch demand {
        case "High": return .green
        case "Medium": return .orange
        default: return .red
        }
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Sold Comps List View
struct SoldCompsListView: View {
    let soldComps: [EbaySoldListing]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sold Listings")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 8) {
                ForEach(soldComps.prefix(10), id: \.title) { comp in
                    SoldCompRow(comp: comp)
                }
            }
            
            if soldComps.count > 10 {
                Text("+ \(soldComps.count - 10) more sold listings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Sold Comp Row
struct SoldCompRow: View {
    let comp: EbaySoldListing
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(comp.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(comp.condition)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(formatDate(comp.soldDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if comp.auction {
                        Text("Auction")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", comp.price))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                if let shipping = comp.shippingCost, shipping > 0 {
                    Text("+$\(String(format: "%.2f", shipping)) ship")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct EbayCompDemoView_Previews: PreviewProvider {
    static var previews: some View {
        EbayCompDemoView()
    }
}
