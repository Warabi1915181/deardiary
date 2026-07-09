//
//  ToDoView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 02/05/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ToDoView: View {
  enum Segment: String, CaseIterable {
    case active = "Active"
    case completed = "Completed"

    var status: ToDoStatus {
      switch self {
      case .active: return .active
      case .completed: return .completed
      }
    }
  }

  @StateObject private var store: ToDoStore
  @State private var selectedSegment: Segment = .active
  @State private var showingNewItemSheet = false
  @State private var showingNewCategorySheet = false
  @State private var showingRenameCategorySheet = false
  @State private var categoryForRename: ToDoCategory?
  @State private var draggingItemID: UUID?
  @State private var pendingCompletionIDs: Set<UUID> = []

  init(store: ToDoStore = ToDoStore()) {
    _store = StateObject(wrappedValue: store)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Our List")
          .font(.regularItalic(size: 48))
          .foregroundStyle(Color("PrimaryForeground"))

        Picker("Status", selection: $selectedSegment) {
          ForEach(Segment.allCases, id: \.self) { segment in
            Text(segment.rawValue).tag(segment)
          }
        }
        .pickerStyle(.segmented)

        if visibleItemsCount == 0 {
          emptyState
        } else {
          categorySections
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("New Item", systemImage: "checklist") {
            showingNewItemSheet = true
          }
          Button("New Category", systemImage: "folder.badge.plus") {
            showingNewCategorySheet = true
          }
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color("PrimaryForeground"))
       
        }
      }
    }
    .sheet(isPresented: $showingNewItemSheet) {
      NewToDoSheet(store: store)
        .presentationDetents([.medium])
    }
    .sheet(isPresented: $showingNewCategorySheet) {
      NewCategorySheet(store: store)
        .presentationDetents([.fraction(0.35)])
    }
    .sheet(isPresented: $showingRenameCategorySheet, onDismiss: {
      categoryForRename = nil
    }) {
      if let categoryForRename {
        RenameCategorySheet(store: store, category: categoryForRename)
          .presentationDetents([.fraction(0.35)])
      }
    }
  }

  private var categorySections: some View {
    VStack(spacing: 12) {
      ForEach(store.categories) { category in
        let items = store.items(for: selectedSegment.status, in: category.id)
        VStack(alignment: .leading, spacing: 8) {
          ToDoCategoryHeader(
            category: category,
            canManage: category.id != ToDoStore.uncategorizedCategoryID,
            onRename: {
              categoryForRename = category
              showingRenameCategorySheet = true
            },
            onDelete: {
              store.deleteCategory(id: category.id)
            }
          )

          VStack(spacing: 8) {
            if items.isEmpty {
              Text(selectedSegment == .active ? "No active items in this category." : "No completed items in this category.")
                .font(.regular(size: 14))
                .foregroundStyle(Color("SecondaryForeground"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
              ForEach(items) { item in
                ToDoItemRow(
                  item: item,
                  isPendingCompletion: pendingCompletionIDs.contains(item.id),
                  status: selectedSegment.status,
                  onToggleComplete: {
                    toggle(item: item)
                  },
                  onDelete: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                      store.deleteItem(id: item.id)
                    }
                  }
                )
                .onDrag {
                  draggingItemID = item.id
                  return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .onDrop(
                  of: [UTType.text],
                  delegate: ToDoItemDropDelegate(
                    destinationItemID: item.id,
                    destinationCategoryID: category.id,
                    status: selectedSegment.status,
                    store: store,
                    draggingItemID: $draggingItemID
                  )
                )
              }
            }
          }
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color("PrimaryBackground"))
          )
          .onDrop(
            of: [UTType.text],
            delegate: ToDoCategoryDropDelegate(
              categoryID: category.id,
              status: selectedSegment.status,
              store: store,
              draggingItemID: $draggingItemID
            )
          )
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: selectedSegment == .active ? "checklist" : "checkmark.circle")
        .font(.system(size: 36))
        .foregroundStyle(Color("SecondaryForeground"))
      Text(selectedSegment == .active ? "No active items yet." : "No completed items yet.")
        .font(.regular(size: 18))
        .foregroundStyle(Color("SecondaryForeground"))
      Text("Tap + to add an item or category.")
        .font(.regular(size: 16))
        .foregroundStyle(Color("SecondaryForeground"))
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("PrimaryBackground"))
    )
  }

  private var visibleItemsCount: Int {
    store.categories
      .reduce(0) { partialResult, category in
        partialResult + store.items(for: selectedSegment.status, in: category.id).count
      }
  }

  private func toggle(item: ToDoItem) {
    if item.status == .active {
      pendingCompletionIDs.insert(item.id)
      withAnimation(.easeInOut(duration: 0.3)) {}
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        pendingCompletionIDs.remove(item.id)
        withAnimation(.easeInOut(duration: 0.25)) {
          store.setCompleted(item.id, completed: true)
        }
      }
      return
    }

    withAnimation(.easeInOut(duration: 0.2)) {
      store.setCompleted(item.id, completed: false)
    }
  }
}

private struct ToDoCategoryHeader: View {
  let category: ToDoCategory
  let canManage: Bool
  let onRename: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text(category.name)
        .font(.regular(size: 20))
        .foregroundStyle(Color("PrimaryForeground"))

      Spacer()

      if canManage {
        Menu {
          Button("Rename", systemImage: "pencil", action: onRename)
          Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 18))
            .foregroundStyle(Color("SecondaryForeground"))
        }
      }
    }
  }
}

private struct ToDoItemRow: View {
  let item: ToDoItem
  let isPendingCompletion: Bool
  let status: ToDoStatus
  let onToggleComplete: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggleComplete) {
        Image(systemName: iconName)
          .font(.system(size: 20))
          .foregroundStyle(item.status == .active ? Color("SageForeground") : Color("SecondaryForeground"))
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.regular(size: 17))
          .foregroundStyle(Color("PrimaryForeground"))
          .strikethrough(status == .completed)
        if !item.details.isEmpty {
          Text(item.details)
            .font(.regular(size: 14))
            .foregroundStyle(Color("SecondaryForeground"))
            .lineLimit(2)
        }
      }

      Spacer(minLength: 8)

      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
          .font(.system(size: 16))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color("SecondaryForeground"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("Muted"))
    )
  }

  private var iconName: String {
    if status == .completed {
      return "checkmark.circle.fill"
    }
    return isPendingCompletion ? "checkmark.circle.fill" : "circle"
  }
}


private struct NewToDoSheet: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var store: ToDoStore

  @State private var title = ""
  @State private var details = ""
  @State private var selectedCategoryID: UUID = ToDoStore.uncategorizedCategoryID
  @State private var showValidationError = false

  var body: some View {
    NavigationStack {
      Form {
        TextField("Item title", text: $title)
          .font(.regular())
        TextField("Details (optional)", text: $details)
          .font(.regular())
        Picker("Category", selection: $selectedCategoryID) {
          ForEach(store.categories) { category in
            Text(category.name).tag(category.id)
          }
        }
        .pickerStyle(.menu)
      }
      .navigationTitle("New Item")
      .onAppear {
        if !store.categories.contains(where: { $0.id == selectedCategoryID }) {
          selectedCategoryID = store.categories.first?.id ?? ToDoStore.uncategorizedCategoryID
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add") {
            let added = store.addItem(title: title, details: details, categoryID: selectedCategoryID)
            if added {
              dismiss()
            } else {
              showValidationError = true
            }
          }
        }
      }
      .alert("Title required", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Please enter a title.")
      }
    }
  }
}

private struct NewCategorySheet: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var store: ToDoStore
  @State private var categoryName = ""
  @State private var showValidationError = false

  var body: some View {
    NavigationStack {
      Form {
        TextField("Category name", text: $categoryName)
          .font(.regular())
      }
      .navigationTitle("New Category")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add") {
            let created = store.addCategory(name: categoryName)
            if created {
              dismiss()
            } else {
              showValidationError = true
            }
          }
        }
      }
      .alert("Invalid category", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Category must be non-empty and unique.")
      }
    }
  }
}

private struct RenameCategorySheet: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var store: ToDoStore
  let category: ToDoCategory
  @State private var categoryName: String
  @State private var showValidationError = false

  init(store: ToDoStore, category: ToDoCategory) {
    self.store = store
    self.category = category
    _categoryName = State(initialValue: category.name)
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Category name", text: $categoryName)
          .font(.regular())
      }
      .navigationTitle("Rename Category")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") {
            let renamed = store.renameCategory(id: category.id, newName: categoryName)
            if renamed {
              dismiss()
            } else {
              showValidationError = true
            }
          }
        }
      }
      .alert("Invalid category", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Category must be non-empty and unique.")
      }
    }
  }
}

private struct ToDoItemDropDelegate: DropDelegate {
  let destinationItemID: UUID
  let destinationCategoryID: UUID
  let status: ToDoStatus
  let store: ToDoStore
  @Binding var draggingItemID: UUID?

  func performDrop(info: DropInfo) -> Bool {
    guard let draggingItemID, draggingItemID != destinationItemID else { return false }
    withAnimation(.easeInOut(duration: 0.2)) {
      store.moveItem(
        id: draggingItemID,
        targetCategoryID: destinationCategoryID,
        targetStatus: status,
        before: destinationItemID
      )
    }
    self.draggingItemID = nil
    return true
  }
}

private struct ToDoCategoryDropDelegate: DropDelegate {
  let categoryID: UUID
  let status: ToDoStatus
  let store: ToDoStore
  @Binding var draggingItemID: UUID?

  func performDrop(info: DropInfo) -> Bool {
    guard let draggingItemID else { return false }
    withAnimation(.easeInOut(duration: 0.2)) {
      store.moveItem(
        id: draggingItemID,
        targetCategoryID: categoryID,
        targetStatus: status,
        before: nil
      )
    }
    self.draggingItemID = nil
    return true
  }
}

#Preview {
  let now = Date()
  let previewState = ToDoPersistedState(
    categories: [
      ToDoCategory(
        id: ToDoStore.uncategorizedCategoryID,
        coupleSpaceID: nil,
        name: "Uncategorized",
        order: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
      ToDoCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        coupleSpaceID: nil,
        name: "Dates",
        order: 1,
        createdAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
    ],
    items: [
      ToDoItem(
        id: UUID(),
        coupleSpaceID: nil,
        title: "Plan weekend picnic",
        details: "Bring camera and blanket",
        categoryID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        status: .active,
        order: 0,
        createdAt: now,
        completedAt: nil,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
      ToDoItem(
        id: UUID(),
        coupleSpaceID: nil,
        title: "Watch sunset at harbor",
        details: "",
        categoryID: ToDoStore.uncategorizedCategoryID,
        status: .completed,
        order: 0,
        createdAt: now,
        completedAt: now,
        updatedAt: now,
        deletedAt: nil,
        modifiedByDeviceID: "preview",
        version: 1
      ),
    ]
  )

  Group {
    ViewWithBackdrop {
      NavigationStack {
        ToDoView(store: ToDoStore(previewState: previewState))
      }
    }
    .preferredColorScheme(.dark)
  }
}
