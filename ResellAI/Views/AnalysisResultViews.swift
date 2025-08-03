import SwiftUI

// MARK: - Enhanced Analysis Result Views with eBay Comps Display

// MARK: - Main Enhanced Analysis Result View
struct CleanAnalysisResultView: View {
    let analysis: AnalysisResult
    let onAddToInventory: () -> Void
    let onDirectList: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Product Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(analysis.itemName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(2)
                            
                            if !analysis.brand.isEmpty {
                                Text(analysis.brand)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("\(String(format: "%.0f", analysis.confidence.overall * 100))% confident")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("$\(String(format: "%.0f", analysis.realisticPrice))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("Market Price")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Quick Stats Row
                    HStack {
                        QuickStat(label: "Condition", value: analysis.actualCondition, color: .blue)
                        QuickStat(label: "Sales", value: "\(analysis.soldListings.count)", color: .purple)
                        QuickStat(label: "Demand", value: analysis.demandLevel, color: .orange)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // eBay Comps Section - NEW!
                if !analysis.soldListings.isEmpty {
                    EbayCompsDisplayView(soldListings: analysis.soldListings)
                } else {
                    NoCompsFoundView()
                }
                
                // Enhanced Pricing Strategy
                EnhancedPricingView(analysis: analysis)
                
                // Market Intelligence
                CleanMarketView(analysis: analysis)
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button(action: onAddToInventory) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add to Inventory")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                    
                    Button(action: onDirectList) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Create eBay Listing")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - eBay Comps Display View - NEW!
struct EbayCompsDisplayView: View {
    let soldListings: [EbaySoldListing]
    @State private var showingAllComps = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("eBay Sold Comps")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(soldListings.count) found")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Market Summary from Real Data
            if !soldListings.isEmpty {
                let prices = soldListings.map { $0.price }
                let avgPrice = prices.reduce(0, +) / Double(prices.count)
                let sortedPrices = prices.sorted()
                let medianPrice = sortedPrices.count % 2 == 0 ?
                    (sortedPrices[sortedPrices.count/2 - 1] + sortedPrices[sortedPrices.count/2]) / 2 :
                    sortedPrices[sortedPrices.count/2]
                
                HStack {
                    MarketStat(title: "Average", value: "$\(String(format: "%.0f", avgPrice))", color: .blue)
                    MarketStat(title: "Median", value: "$\(String(format: "%.0f", medianPrice))", color: .green)
                    MarketStat(title: "Range", value: "$\(String(format: "%.0f", sortedPrices.first ?? 0))-\(String(format: "%.0f", sortedPrices.last ?? 0))", color: .orange)
                }
            }
            
            // Recent Comps List
            VStack(spacing: 8) {
                ForEach(soldListings.prefix(showingAllComps ? soldListings.count : 5), id: \.title) { listing in
                    EbayCompRow(listing: listing)
                }
            }
            
            // Show More/Less Button
            if soldListings.count > 5 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingAllComps.toggle()
                    }
                }) {
                    HStack {
                        Text(showingAllComps ? "Show Less" : "Show All \(soldListings.count) Comps")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: showingAllComps ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Individual eBay Comp Row
struct EbayCompRow: View {
    let listing: EbaySoldListing
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(listing.condition)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(formatSoldDate(listing.soldDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if listing.auction {
                        Text("Auction")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.0f", listing.price))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                if let shipping = listing.shippingCost, shipping > 0 {
                    Text("+$\(String(format: "%.0f", shipping)) ship")
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
    
    private func formatSoldDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - No Comps Found View
struct NoCompsFoundView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("No Recent Sales Found")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Using estimated pricing based on category and brand")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("💡 Try different keywords or check spelling")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Pricing View with Real Data Context
struct EnhancedPricingView: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing Strategy")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !analysis.soldListings.isEmpty {
                Text("Based on \(analysis.soldListings.count) recent eBay sales")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
            
            HStack(spacing: 10) {
                PriceOption(
                    title: "Quick",
                    price: analysis.quickSalePrice,
                    subtitle: "Fast sale",
                    color: .orange
                )
                
                PriceOption(
                    title: "Recommended",
                    price: analysis.realisticPrice,
                    subtitle: "Best value",
                    color: .blue,
                    isHighlighted: true
                )
                
                PriceOption(
                    title: "Max",
                    price: analysis.maxProfitPrice,
                    subtitle: "Max profit",
                    color: .green
                )
            }
            
            // Pricing Confidence Indicator
            HStack {
                Text("Pricing Confidence:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let confidence = analysis.confidence.pricing
                let confidenceText = confidence > 0.8 ? "High" : confidence > 0.6 ? "Medium" : "Low"
                let confidenceColor: Color = confidence > 0.8 ? .green : confidence > 0.6 ? .orange : .red
                
                Text(confidenceText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(confidenceColor)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Quick Stat Component
struct QuickStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Price Option Component
struct PriceOption: View {
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
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isHighlighted ? .white : color)
            
            Text("$\(String(format: "%.0f", price))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isHighlighted ? .white : color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isHighlighted ? color : color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: isHighlighted ? 0 : 1)
        )
    }
}

// MARK: - Clean Market View
struct CleanMarketView: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Intelligence")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                MarketStat(
                    title: "Competition",
                    value: "\(analysis.competitorCount)",
                    color: analysis.competitorCount > 50 ? .red : .green
                )
                
                MarketStat(
                    title: "Trend",
                    value: analysis.marketTrend,
                    color: .blue
                )
                
                MarketStat(
                    title: "Score",
                    value: "\(analysis.resalePotential)/10",
                    color: getScoreColor(analysis.resalePotential)
                )
            }
            
            if analysis.averagePrice > 0 {
                HStack {
                    Text("Average market price:")
                    Spacer()
                    Text("$\(String(format: "%.2f", analysis.averagePrice))")
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func getScoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 6...7: return .blue
        case 4...5: return .orange
        default: return .red
        }
    }
}

// MARK: - Market Stat Component
struct MarketStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - eBay Condition Card
struct CleanEbayConditionCard: View {
    let condition: EbayCondition
    let assessment: EbayConditionAssessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Condition Assessment")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(condition.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(condition.color)
                    
                    Text(condition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.0f", assessment.conditionConfidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Condition Notes
            if !assessment.conditionNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(assessment.conditionNotes, id: \.self) { note in
                        Text("• \(note)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(condition.color.opacity(0.1))
        .cornerRadius(12)
    }
}
