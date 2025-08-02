import SwiftUI
import PhotosUI

// MARK: - Apple-Style Inventory Organization Views

// MARK: - Main Apple Inventory Organization View
struct InventoryOrganizationView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @State private var selectedCategory: String?
    @State private var showingStorageGuide = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Apple-style header
                    VStack(spacing: 8) {
                        Text("Storage")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Smart inventory organization")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Quick storage stats
                    AppleStorageStats(inventoryManager: inventoryManager)
                    
                    // Category grid
                    AppleCategoryGrid(
                        inventoryManager: inventoryManager,
                        onCategorySelected: { selectedCategory = $0 }
                    )
                    
                    // Storage actions
                    AppleStorageActions(onStorageGuide: { showingStorageGuide = true })
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingStorageGuide) {
            StorageGuideView()
        }
        .sheet(item: Binding<CategorySelection?>(
            get: {
                guard let category = selectedCategory else { return nil }
                return CategorySelection(letter: category)
            },
            set: { _ in selectedCategory = nil }
        )) { selection in
            CategoryDetailView(categoryLetter: selection.letter)
                .environmentObject(inventoryManager)
        }
    }
}

// Helper struct for sheet presentation
struct CategorySelection: Identifiable {
    let id = UUID()
    let letter: String
}

// MARK: - Apple Storage Stats
struct AppleStorageStats: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        HStack(spacing: 16) {
            AppleStorageStat(
                title: "Total Items",
                value: "\(inventoryManager.items.count)",
                color: .blue
            )
            
            AppleStorageStat(
                title: "Categories",
                value: "\(inventoryManager.getInventoryOverview().count)",
                color: .green
            )
            
            AppleStorageStat(
                title: "Packaged",
                value: "\(inventoryManager.getPackagedItems().count)",
                color: .orange
            )
        }
    }
}

struct AppleStorageStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Apple Category Grid
struct AppleCategoryGrid: View {
    let inventoryManager: InventoryManager
    let onCategorySelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.system(size: 22, weight: .bold))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(inventoryManager.getInventoryOverview(), id: \.letter) { overview in
                    AppleCategoryCard(
                        letter: overview.letter,
                        category: overview.category,
                        itemCount: overview.count,
                        items: overview.items
                    ) {
                        onCategorySelected(overview.letter)
                    }
                }
            }
        }
    }
}

// MARK: - Apple Category Card
struct AppleCategoryCard: View {
    let letter: String
    let category: String
    let itemCount: Int
    let items: [InventoryItem]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Category Letter with refined styling
                ZStack {
                    Circle()
                        .fill(getColorForLetter(letter))
                        .frame(width: 48, height: 48)
                    
                    Text(letter)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text(category)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Item preview with Apple styling
                    if !items.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(items.prefix(3), id: \.id) { item in
                                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 20, height: 20)
                                        .cornerRadius(4)
                                        .clipped()
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray4))
                                        .frame(width: 20, height: 20)
                                }
                            }
                            
                            if items.count > 3 {
                                Text("+\(items.count - 3)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: getColorForLetter(letter).opacity(0.1), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func getColorForLetter(_ letter: String) -> Color {
        switch letter {
        case "A": return .red
        case "B": return .orange
        case "C": return .blue
        case "D": return .green
        case "E": return .purple
        case "F": return .pink
        case "G": return .mint
        case "H": return .cyan
        case "I": return .indigo
        case "J": return .brown
        case "K": return .yellow
        case "L": return .teal
        case "M": return .primary
        default: return .gray
        }
    }
}

// MARK: - Apple Storage Actions
struct AppleStorageActions: View {
    let onStorageGuide: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Management")
                .font(.system(size: 22, weight: .bold))
            
            HStack(spacing: 16) {
                AppleStorageActionButton(
                    title: "Storage Guide",
                    subtitle: "Organization tips",
                    color: .green,
                    icon: "book.fill",
                    action: onStorageGuide
                )
                
                AppleStorageActionButton(
                    title: "More Features",
                    subtitle: "Coming soon",
                    color: .gray,
                    icon: "plus.circle.fill",
                    action: {}
                )
            }
        }
    }
}

struct AppleStorageActionButton: View {
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

// MARK: - Category Detail View
struct CategoryDetailView: View {
    let categoryLetter: String
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingStorageUpdate = false
    @State private var selectedItems: Set<UUID> = []
    
    var categoryItems: [InventoryItem] {
        inventoryManager.getItemsByInventoryLetter(categoryLetter)
    }
    
    var categoryInfo: InventoryCategory? {
        InventoryCategory.allCases.first { $0.inventoryLetter == categoryLetter }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Category header with Apple styling
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(getColorForLetter(categoryLetter))
                                .frame(width: 80, height: 80)
                            
                            Text(categoryLetter)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text(categoryInfo?.rawValue ?? "Unknown Category")
                                .font(.system(size: 28, weight: .bold))
                            
                            Text("\(categoryItems.count) item\(categoryItems.count == 1 ? "" : "s")")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Storage tips
                    if let category = categoryInfo {
                        AppleStorageTipsCard(category: category)
                    }
                    
                    // Items list
                    if !categoryItems.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Items")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(categoryItems) { item in
                                    AppleCategoryItemRow(item: item) { updatedItem in
                                        inventoryManager.updateItem(updatedItem)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.secondary)
                            
                            Text("No items in this category")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Category \(categoryLetter)")
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
    
    private func getColorForLetter(_ letter: String) -> Color {
        switch letter {
        case "A": return .red
        case "B": return .orange
        case "C": return .blue
        case "D": return .green
        case "E": return .purple
        case "F": return .pink
        case "G": return .mint
        case "H": return .cyan
        case "I": return .indigo
        case "J": return .brown
        case "K": return .yellow
        case "L": return .teal
        case "M": return .primary
        default: return .gray
        }
    }
}

// MARK: - Apple Storage Tips Card
struct AppleStorageTipsCard: View {
    let category: InventoryCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Tips")
                .font(.system(size: 20, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(category.storageTips.prefix(3), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(tip)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Apple Category Item Row
struct AppleCategoryItemRow: View {
    let item: InventoryItem
    let onUpdate: (InventoryItem) -> Void
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 16) {
                // Item Image
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
                
                // Item Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.inventoryCode.isEmpty ? "No Code" : item.inventoryCode)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item.inventoryCode.isEmpty ? .red : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(item.inventoryCode.isEmpty ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        )
                    
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Text(item.condition)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        
                        if item.isPackaged {
                            Text("Packaged")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                        
                        if !item.storageLocation.isEmpty {
                            Text(item.storageLocation)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Price and Status
                VStack(alignment: .trailing, spacing: 6) {
                    Text("$\(String(format: "%.0f", item.suggestedPrice))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text(item.status.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(item.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.status.color.opacity(0.1))
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ItemDetailView(item: item, onUpdate: onUpdate)
        }
    }
}

// MARK: - Apple Storage Guide View
struct StorageGuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Storage Guide")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Organize your inventory for maximum efficiency")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    VStack(spacing: 16) {
                        ForEach(InventoryCategory.allCases.prefix(8), id: \.self) { category in
                            AppleCategoryStorageGuide(category: category)
                        }
                    }
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
    }
}

// MARK: - Apple Category Storage Guide
struct AppleCategoryStorageGuide: View {
    let category: InventoryCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(getColorForCategory(category))
                        .frame(width: 40, height: 40)
                    
                    Text(category.inventoryLetter)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(category.storageTips.prefix(3), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(getColorForCategory(category))
                            .frame(width: 4, height: 4)
                            .padding(.top, 8)
                        
                        Text(tip)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(getColorForCategory(category).opacity(0.05))
        )
    }
    
    private func getColorForCategory(_ category: InventoryCategory) -> Color {
        switch category.inventoryLetter {
        case "A": return .red
        case "B": return .orange
        case "C": return .blue
        case "D": return .green
        case "E": return .purple
        case "F": return .pink
        case "G": return .mint
        case "H": return .cyan
        case "I": return .indigo
        case "J": return .brown
        case "K": return .yellow
        case "L": return .teal
        case "M": return .primary
        default: return .gray
        }
    }
}

// MARK: - Apple Smart Inventory List View
struct SmartInventoryListView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var googleSheetsService: GoogleSheetsService
    @State private var searchText = ""
    @State private var filterStatus: ItemStatus?
    @State private var showingBarcodeLookup = false
    @State private var scannedBarcode: String?
    @State private var selectedItem: InventoryItem?
    @State private var showingAutoListing = false
    @State private var showingItemEditor = false
    @State private var itemToEdit: InventoryItem?
    
    var filteredItems: [InventoryItem] {
        inventoryManager.items
            .filter { item in
                if let status = filterStatus {
                    return item.status == status
                }
                return true
            }
            .filter { item in
                if searchText.isEmpty {
                    return true
                }
                return item.name.localizedCaseInsensitiveContains(searchText) ||
                       item.source.localizedCaseInsensitiveContains(searchText) ||
                       item.inventoryCode.localizedCaseInsensitiveContains(searchText) ||
                       item.brand.localizedCaseInsensitiveContains(searchText)
            }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Apple-style header
                    VStack(spacing: 16) {
                        Text("Inventory")
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Search bar with Apple styling
                        HStack(spacing: 12) {
                            AppleSearchBar(text: $searchText)
                            
                            Button(action: { showingBarcodeLookup = true }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    
                    // Filter bar
                    if filteredItems.count != inventoryManager.items.count || filterStatus != nil {
                        AppleFilterBar(
                            currentFilter: filterStatus,
                            itemCount: filteredItems.count,
                            totalCount: inventoryManager.items.count,
                            onClearFilter: { filterStatus = nil }
                        )
                    }
                    
                    // Items list
                    if filteredItems.isEmpty {
                        AppleEmptyState()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                AppleInventoryItemRow(item: item) { updatedItem in
                                    inventoryManager.updateItem(updatedItem)
                                    googleSheetsService.updateItem(updatedItem)
                                } onAutoList: { item in
                                    selectedItem = item
                                    showingAutoListing = true
                                } onEdit: { item in
                                    itemToEdit = item
                                    showingItemEditor = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            BarcodeScannerView(scannedCode: $scannedBarcode)
                .onDisappear {
                    if let barcode = scannedBarcode {
                        lookupItemByBarcode(barcode: barcode)
                    }
                }
        }
        .sheet(isPresented: $showingAutoListing) {
            if let item = selectedItem {
                AutoListingView(item: item)
            }
        }
        .sheet(isPresented: $showingItemEditor) {
            if let item = itemToEdit {
                InventoryItemEditorView(item: item) { updatedItem in
                    inventoryManager.updateItem(updatedItem)
                    googleSheetsService.updateItem(updatedItem)
                    showingItemEditor = false
                    itemToEdit = nil
                }
                .environmentObject(inventoryManager)
            }
        }
    }
    
    private func lookupItemByBarcode(barcode: String) {
        if let item = inventoryManager.findItem(byInventoryCode: barcode) {
            selectedItem = item
            showingAutoListing = true
        }
    }
}

// MARK: - Apple Search Bar
struct AppleSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("Search items...", text: $text)
                .font(.system(size: 17, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Apple Filter Bar
struct AppleFilterBar: View {
    let currentFilter: ItemStatus?
    let itemCount: Int
    let totalCount: Int
    let onClearFilter: () -> Void
    
    var body: some View {
        HStack {
            if let status = currentFilter {
                Text("Filter: \(status.rawValue)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Text("\(itemCount) of \(totalCount)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if currentFilter != nil {
                Button("Clear", action: onClearFilter)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Apple Empty State
struct AppleEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Items Found")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Try adjusting your search or filters")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Apple Inventory Item Row
struct AppleInventoryItemRow: View {
    let item: InventoryItem
    let onUpdate: (InventoryItem) -> Void
    let onAutoList: (InventoryItem) -> Void
    let onEdit: (InventoryItem) -> Void
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 16) {
                // Item Image
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.secondary)
                        )
                }
                
                // Item Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.inventoryCode.isEmpty ? "No Code" : item.inventoryCode)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(item.inventoryCode.isEmpty ? .red : .blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(item.inventoryCode.isEmpty ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                            )
                        
                        Spacer()
                        
                        Text("#\(item.itemNumber)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        if !item.brand.isEmpty {
                            Text(item.brand)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(item.source) • $\(String(format: "%.0f", item.purchasePrice))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if !item.storageLocation.isEmpty {
                            Text(item.storageLocation)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                    }
                }
                
                Spacer()
                
                // Price and Actions
                VStack(alignment: .trailing, spacing: 8) {
                    Text(item.status.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(item.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.status.color.opacity(0.1))
                        )
                    
                    Text("$\(String(format: "%.0f", item.suggestedPrice))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 8) {
                        Button(action: { onEdit(item) }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange.opacity(0.1))
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button(action: { onAutoList(item) }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
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
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ItemDetailView(item: item, onUpdate: onUpdate)
        }
    }
}

// MARK: - Item Detail View
struct ItemDetailView: View {
    @State var item: InventoryItem
    let onUpdate: (InventoryItem) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Item preview
                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 240)
                            .cornerRadius(16)
                            .clipped()
                    }
                    
                    // Item info
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.inventoryCode)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                
                                Text(item.name)
                                    .font(.system(size: 24, weight: .bold))
                                
                                if !item.brand.isEmpty {
                                    Text(item.brand)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("$\(String(format: "%.0f", item.suggestedPrice))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text(item.status.rawValue)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(item.status.color)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(item.status.color.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button("Edit Item") {
                            showingEditor = true
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.orange)
                        )
                        .buttonStyle(ScaleButtonStyle())
                        
                        HStack(spacing: 12) {
                            Button(item.isPackaged ? "Packaged ✓" : "Mark Packaged") {
                                markAsPackaged()
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(item.isPackaged ? Color.green : Color.blue)
                            )
                            .buttonStyle(ScaleButtonStyle())
                            
                            Button("Update Status") {
                                updateStatus()
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple)
                            )
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Item Details")
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
        .sheet(isPresented: $showingEditor) {
            InventoryItemEditorView(item: item, onSave: onUpdate)
        }
    }
    
    private func markAsPackaged() {
        item.isPackaged.toggle()
        if item.isPackaged {
            item.packagedDate = Date()
        } else {
            item.packagedDate = nil
        }
        onUpdate(item)
    }
    
    private func updateStatus() {
        let allCases = ItemStatus.allCases
        if let currentIndex = allCases.firstIndex(of: item.status) {
            let nextIndex = (currentIndex + 1) % allCases.count
            item.status = allCases[nextIndex]
            onUpdate(item)
        }
    }
}

// MARK: - Inventory Item Editor
struct InventoryItemEditorView: View {
    @State var item: InventoryItem
    let onSave: (InventoryItem) -> Void
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $item.name)
                    TextField("Brand", text: $item.brand)
                    TextField("Size", text: $item.size)
                    TextField("Color", text: $item.colorway)
                }
                
                Section("Pricing") {
                    HStack {
                        Text("Purchase Price")
                        Spacer()
                        TextField("0.00", value: $item.purchasePrice, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Suggested Price")
                        Spacer()
                        TextField("0.00", value: $item.suggestedPrice, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Storage") {
                    TextField("Storage Location", text: $item.storageLocation)
                    TextField("Bin Number", text: $item.binNumber)
                    Toggle("Packaged", isOn: $item.isPackaged)
                }
                
                Section("Status") {
                    Picker("Status", selection: $item.status) {
                        ForEach(ItemStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(item)
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }
}
