import SwiftUI
import Vision
import AVFoundation
import MessageUI

// MARK: - Apple-Style Dashboard View
struct DashboardView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @State private var showingPortfolioTracking = false
    @State private var showingBusinessIntelligence = false
    @State private var showingProfitOptimizer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Apple-style header
                    VStack(spacing: 8) {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Your reselling business overview")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Key metrics with Apple card styling
                    AppleMetricsGrid(inventoryManager: inventoryManager)
                    
                    // Quick actions with refined styling
                    AppleQuickActions(
                        onPortfolio: { showingPortfolioTracking = true },
                        onIntelligence: { showingBusinessIntelligence = true },
                        onOptimizer: { showingProfitOptimizer = true }
                    )
                    
                    // Performance summary
                    ApplePerformanceSummary(inventoryManager: inventoryManager)
                    
                    // Recent activity
                    AppleRecentActivity(inventoryManager: inventoryManager)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingPortfolioTracking) {
            PortfolioTrackingView()
                .environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showingBusinessIntelligence) {
            BusinessIntelligenceView()
                .environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showingProfitOptimizer) {
            ProfitOptimizerView()
                .environmentObject(inventoryManager)
        }
    }
}

// MARK: - Apple Metrics Grid
struct AppleMetricsGrid: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            
            AppleMetricCard(
                title: "Total Value",
                value: "$\(String(format: "%.0f", inventoryManager.totalEstimatedValue))",
                color: .blue,
                icon: "dollarsign.circle.fill"
            )
            
            AppleMetricCard(
                title: "Total Profit",
                value: "$\(String(format: "%.0f", inventoryManager.totalProfit))",
                color: .green,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            AppleMetricCard(
                title: "Items",
                value: "\(inventoryManager.items.count)",
                color: .purple,
                icon: "cube.box.fill"
            )
            
            AppleMetricCard(
                title: "Avg ROI",
                value: "\(String(format: "%.0f", inventoryManager.averageROI))%",
                color: .orange,
                icon: "percent"
            )
        }
    }
}

struct AppleMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Apple Quick Actions
struct AppleQuickActions: View {
    let onPortfolio: () -> Void
    let onIntelligence: () -> Void
    let onOptimizer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 22, weight: .bold))
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    AppleActionCard(
                        title: "Portfolio",
                        subtitle: "Track performance",
                        color: .blue,
                        icon: "chart.bar.fill",
                        action: onPortfolio
                    )
                    
                    AppleActionCard(
                        title: "Intelligence",
                        subtitle: "Market insights",
                        color: .purple,
                        icon: "brain.head.profile",
                        action: onIntelligence
                    )
                }
                
                HStack(spacing: 12) {
                    AppleActionCard(
                        title: "Optimizer",
                        subtitle: "Maximize profit",
                        color: .green,
                        icon: "wand.and.stars",
                        action: onOptimizer
                    )
                    
                    AppleActionCard(
                        title: "Market Ops",
                        subtitle: "Coming soon",
                        color: .gray,
                        icon: "target",
                        action: {}
                    )
                }
            }
        }
    }
}

struct AppleActionCard: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.08))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Apple Performance Summary
struct ApplePerformanceSummary: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Summary")
                .font(.system(size: 22, weight: .bold))
            
            VStack(spacing: 12) {
                ApplePerformanceRow(
                    title: "Items Listed",
                    value: "\(inventoryManager.listedItems)",
                    trend: "+12%",
                    isPositive: true
                )
                
                ApplePerformanceRow(
                    title: "Items Sold",
                    value: "\(inventoryManager.soldItems)",
                    trend: "+8%",
                    isPositive: true
                )
                
                ApplePerformanceRow(
                    title: "Success Rate",
                    value: "\(getSuccessRate())%",
                    trend: "+5%",
                    isPositive: true
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func getSuccessRate() -> Int {
        let sold = inventoryManager.soldItems
        let total = inventoryManager.items.count
        return total > 0 ? Int(Double(sold) / Double(total) * 100) : 0
    }
}

struct ApplePerformanceRow: View {
    let title: String
    let value: String
    let trend: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(trend)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isPositive ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isPositive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Apple Recent Activity
struct AppleRecentActivity: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 22, weight: .bold))
            
            if inventoryManager.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary)
                    
                    Text("No items yet")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Start by analyzing your first item")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(inventoryManager.recentItems.prefix(5)) { item in
                        AppleActivityRow(item: item)
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
    }
}

struct AppleActivityRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Item Image with refined styling
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .cornerRadius(12)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                    )
            }
            
            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(item.source)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if item.estimatedROI > 100 {
                        Text("High ROI")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.1))
                            )
                    }
                }
            }
            
            Spacer()
            
            // Price and Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.status.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(item.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.status.color.opacity(0.1))
                    )
                
                if item.estimatedProfit > 0 {
                    Text("$\(String(format: "%.0f", item.estimatedProfit))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Future Feature Views with Apple Styling
struct PortfolioTrackingView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header icon
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 16) {
                        Text("Portfolio Tracking")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Advanced portfolio analytics coming soon")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Preview Stats
                    VStack(spacing: 16) {
                        ApplePreviewStat(
                            title: "Total Items",
                            value: "\(inventoryManager.items.count)"
                        )
                        
                        ApplePreviewStat(
                            title: "Total Value",
                            value: "$\(String(format: "%.0f", inventoryManager.totalEstimatedValue))"
                        )
                        
                        ApplePreviewStat(
                            title: "Average ROI",
                            value: "\(String(format: "%.0f", inventoryManager.averageROI))%"
                        )
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
            .navigationTitle("Portfolio")
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
    }
}

struct BusinessIntelligenceView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.purple)
                    
                    VStack(spacing: 16) {
                        Text("Business Intelligence")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("AI-powered insights coming soon")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Preview Insights
                    VStack(spacing: 16) {
                        AppleInsightRow(title: "Best Category", value: getBestCategory())
                        AppleInsightRow(title: "Top Source", value: getTopSource())
                        AppleInsightRow(title: "Success Rate", value: "\(getSuccessRate())%")
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
            .navigationTitle("Intelligence")
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
    }
    
    private func getBestCategory() -> String {
        let categories = Dictionary(grouping: inventoryManager.items, by: { $0.category })
        let categoryROI = categories.mapValues { items in
            items.reduce(0) { $0 + $1.estimatedROI } / Double(items.count)
        }
        return categoryROI.max(by: { $0.value < $1.value })?.key ?? "Mixed"
    }
    
    private func getTopSource() -> String {
        let sources = Dictionary(grouping: inventoryManager.items, by: { $0.source })
        return sources.max(by: { $0.value.count < $1.value.count })?.key ?? "Various"
    }
    
    private func getSuccessRate() -> Int {
        let sold = inventoryManager.soldItems
        let total = inventoryManager.items.count
        return total > 0 ? Int(Double(sold) / Double(total) * 100) : 0
    }
}

struct ProfitOptimizerView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 16) {
                        Text("Profit Optimizer")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Maximize your profit potential")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Current Profit Summary
                    VStack(spacing: 16) {
                        AppleProfitStat(
                            title: "Current Profit",
                            value: "$\(String(format: "%.0f", inventoryManager.totalProfit))",
                            color: .green
                        )
                        
                        AppleProfitStat(
                            title: "Potential Profit",
                            value: "$\(String(format: "%.0f", inventoryManager.totalEstimatedValue * 0.3))",
                            color: .blue
                        )
                        
                        AppleProfitStat(
                            title: "Optimization Score",
                            value: "85%",
                            color: .orange
                        )
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
            .navigationTitle("Optimizer")
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
    }
}

// MARK: - Apple-Style Supporting Components

struct ApplePreviewStat: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AppleInsightRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

struct AppleProfitStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
    }
}
