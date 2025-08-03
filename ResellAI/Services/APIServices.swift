//
//  APIServices.swift
//  ResellAI
//
//  Google Sheets Service Only (MarketResearchService moved to its own file)
//

import SwiftUI
import Foundation

// MARK: - Google Sheets Service
class GoogleSheetsService: ObservableObject {
    @Published var spreadsheetId = Configuration.spreadsheetID
    @Published var isConnected = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus = "Ready to sync"
    
    init() {
        authenticate()
    }
    
    func authenticate() {
        print("🔗 Google Sheets Service Initialized")
        isConnected = !Configuration.googleScriptURL.isEmpty
        syncStatus = isConnected ? "Connected" : "Not configured"
    }
    
    func syncInventory(_ items: [InventoryItem]) {
        guard isConnected else {
            print("❌ Google Sheets not connected")
            return
        }
        
        isSyncing = true
        syncStatus = "Syncing..."
        
        // Convert inventory to sheet format
        let sheetData: [[String: Any]] = items.map { item in
            return [
                "Item Number": item.itemNumber,
                "Name": item.name,
                "Category": item.category,
                "Purchase Price": item.purchasePrice,
                "Suggested Price": item.suggestedPrice,
                "Source": item.source,
                "Condition": item.condition,
                "Status": item.status.rawValue,
                "Date Added": ISO8601DateFormatter().string(from: item.dateAdded),
                "eBay URL": item.ebayURL ?? "",
                "Brand": item.brand,
                "Model": item.exactModel,
                "Size": item.size,
                "Colorway": item.colorway,
                "Inventory Code": item.inventoryCode,
                "Storage Location": item.storageLocation
            ]
        }
        
        // Send to Google Sheets via Apps Script
        sendToGoogleSheets(data: sheetData) { [weak self] success in
            DispatchQueue.main.async {
                self?.isSyncing = false
                if success {
                    self?.lastSyncDate = Date()
                    self?.syncStatus = "✅ Synced successfully"
                } else {
                    self?.syncStatus = "❌ Sync failed"
                }
            }
        }
    }
    
    private func sendToGoogleSheets(data: [[String: Any]], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: Configuration.googleScriptURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "action": "updateInventory",
            "data": data
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ Google Sheets payload error: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Google Sheets sync error: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Google Sheets response: \(httpResponse.statusCode)")
            }
            
            completion(true)
        }.resume()
    }
    
    func updateItem(_ item: InventoryItem) {
        syncInventory([item])
    }
    
    func syncAllItems(_ items: [InventoryItem]) {
        syncInventory(items)
    }
    
    func uploadItem(_ item: InventoryItem) {
        syncInventory([item])
    }
}
