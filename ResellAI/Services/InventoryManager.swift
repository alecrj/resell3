//
//  InventoryManager.swift
//  ResellAI
//
//  Simple inventory tracking for analyzed items
//

import Foundation

@MainActor
class InventoryManager: ObservableObject {
    @Published var inventory: [InventoryItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let inventoryKey = "resellai_inventory"
    
    init() {
        loadInventory()
    }
    
    // MARK: - Core Functions
    
    func addItem(from analysis: ItemAnalysis, listingPrice: Double, status: InventoryStatus = .analyzed) {
        let item = InventoryItem(
            analysis: analysis,
            listingPrice: listingPrice,
            status: status
        )
        
        inventory.insert(item, at: 0)
        saveInventory()
    }
    
    func updateItemStatus(_ itemID: UUID, status: InventoryStatus) {
        if let index = inventory.firstIndex(where: { $0.id == itemID }) {
            inventory[index].status = status
            inventory[index].updatedAt = Date()
            saveInventory()
        }
    }
    
    func removeItem(_ itemID: UUID) {
        inventory.removeAll { $0.id == itemID }
        saveInventory()
    }
    
    func clearInventory() {
        inventory.removeAll()
        saveInventory()
    }
    
    // MARK: - Data Persistence
    
    private func saveInventory() {
        if let encoded = try? JSONEncoder().encode(inventory) {
            userDefaults.set(encoded, forKey: inventoryKey)
        }
    }
    
    private func loadInventory() {
        guard let data = userDefaults.data(forKey: inventoryKey),
              let decoded = try? JSONDecoder().decode([InventoryItem].self, from: data) else {
            return
        }
        
        inventory = decoded
    }
    
    // MARK: - Analytics
    
    var totalValue: Double {
        inventory.reduce(0) { $0 + $1.listingPrice }
    }
    
    var totalItems: Int {
        inventory.count
    }
    
    var listedItems: [InventoryItem] {
        inventory.filter { $0.status == .listed }
    }
    
    var soldItems: [InventoryItem] {
        inventory.filter { $0.status == .sold }
    }
    
    var pendingItems: [InventoryItem] {
        inventory.filter { $0.status == .analyzed }
    }
}

// MARK: - Inventory Item Model

struct InventoryItem: Codable, Identifiable {
    let id = UUID()
    let title: String
    let brand: String
    let category: String
    let condition: ItemCondition
    let listingPrice: Double
    let suggestedPrice: Double
    let confidence: Double
    let createdAt: Date
    var updatedAt: Date
    var status: InventoryStatus
    
    init(analysis: ItemAnalysis, listingPrice: Double, status: InventoryStatus) {
        self.title = analysis.title
        self.brand = analysis.brand
        self.category = analysis.category
        self.condition = analysis.condition
        self.listingPrice = listingPrice
        self.suggestedPrice = analysis.suggestedPrice
        self.confidence = analysis.confidence
        self.createdAt = analysis.createdAt
        self.updatedAt = Date()
        self.status = status
    }
}

// MARK: - Inventory Status

enum InventoryStatus: String, CaseIterable, Codable {
    case analyzed = "Analyzed"
    case listed = "Listed on eBay"
    case sold = "Sold"
    case draft = "Draft"
    
    var color: String {
        switch self {
        case .analyzed: return "orange"
        case .listed: return "blue"
        case .sold: return "green"
        case .draft: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .analyzed: return "magnifyingglass"
        case .listed: return "list.bullet"
        case .sold: return "checkmark.circle"
        case .draft: return "doc"
        }
    }
}
