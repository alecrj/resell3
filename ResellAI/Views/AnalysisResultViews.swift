import SwiftUI

// MARK: - Clean Analysis Result Views

// MARK: - Main Clean Analysis Result View
struct CleanAnalysisResultView: View {
    let analysis: AnalysisResult
    let onAddToInventory: () -> Void
    let onDirectList: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
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
            
            // Clean Pricing Strategy
            CleanPricingView(analysis: analysis)
            
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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

// MARK: - Clean Pricing View
struct CleanPricingView: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing Strategy")
                .font(.headline)
                .fontWeight(.semibold)
            
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
            
            if !analysis.soldListings.isEmpty {
                Text("Based on \(analysis.soldListings.count) recent sales")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
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
