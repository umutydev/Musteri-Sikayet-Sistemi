import SwiftUI

struct CategoryManagementView: View {
    @State private var categories: [Category] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading { ProgressView() }
            else {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name).font(.headline)
                        if let desc = category.description {
                            Text(desc).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Sistem Kategorileri")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Kategori Ekle") {} } }
        .task { categories = (try? await CategoryService.shared.listCategories()) ?? [] }
    }
}
