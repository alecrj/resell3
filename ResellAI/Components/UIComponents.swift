//
//  UIComponents.swift
//  ResellAI
//
//  Reusable UI components (CameraView moved to ContentView)
//

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: String
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if let onRetry = onRetry {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// MARK: - Success View
struct SuccessView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Success!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Done", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// MARK: - Price Tag View
struct PriceTagView: View {
    let price: Double
    let label: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(price, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
        }
        .padding()
        .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Condition Badge
struct ConditionBadgeView: View {
    let condition: ItemCondition
    
    var body: some View {
        Text(condition.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(conditionColor.opacity(0.2))
            .foregroundColor(conditionColor)
            .cornerRadius(6)
    }
    
    private var conditionColor: Color {
        switch condition {
        case .newWithTags, .newWithoutTags, .newOther:
            return .green
        case .likeNew, .excellent:
            return .blue
        case .veryGood, .good:
            return .orange
        case .acceptable, .forParts:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingView(message: "Analyzing item...")
        
        ErrorView(error: "Failed to connect to eBay") {
            print("Retry tapped")
        }
        
        SuccessView(message: "Item posted to eBay successfully!") {
            print("Dismiss tapped")
        }
        
        HStack {
            PriceTagView(price: 45.99, label: "Quick Sale", isSelected: false)
            PriceTagView(price: 55.99, label: "Competitive", isSelected: true)
            PriceTagView(price: 65.99, label: "Premium", isSelected: false)
        }
        
        ConditionBadgeView(condition: .excellent)
    }
    .padding()
}
