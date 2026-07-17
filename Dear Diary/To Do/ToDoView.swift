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
    case active = "Dreaming"
    case completed = "Done"

    var status: ToDoStatus {
      switch self {
      case .active: return .active
      case .completed: return .completed
      }
    }
  }

  var store: ToDoStore
  var diaryStore: DiaryStore
  @State private var selectedSegment: Segment = .active
  @State private var showingNewItemSheet = false
  @State private var showingNewCategorySheet = false
  @State private var showingRenameCategorySheet = false
  @State private var categoryForRename: ToDoCategory?
  @State private var draggingItemID: UUID?
  @State private var pendingCompletionIDs: Set<UUID> = []
  @State private var bridgingItem: ToDoItem?

  init(store: ToDoStore = ToDoStore(), diaryStore: DiaryStore = DiaryStore()) {
    self.store = store
    self.diaryStore = diaryStore
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Our List")
          .font(.screenTitle)
          .foregroundStyle(Color("RomanceForeground"))

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
          Button("New Idea", systemImage: "sparkles") {
            showingNewItemSheet = true
          }
          Button("New Category", systemImage: "folder.badge.plus") {
            showingNewCategorySheet = true
          }
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color("RomanceForeground"))
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
    .sheet(item: $bridgingItem) { item in
      memoryBridgeEditor(for: item)
    }
  }

  /// The memory bridge: a finished bucket item opens a diary entry — either the
  /// one already linked to it, or a fresh entry prefilled with the item's title
  /// that links back on save. Optional: the item stays "Done" whether or not a
  /// memory is ever written. Mirrors the milestone→diary bridge.
  @ViewBuilder
  private func memoryBridgeEditor(for item: ToDoItem) -> some View {
    if
      let entryID = item.linkedDiaryEntryID,
      let entry = diaryStore.entryRecord(id: entryID)
    {
      DiaryEntryEditorView(store: diaryStore, entry: entry)
    } else {
      DiaryEntryEditorView(
        store: diaryStore,
        prefillTitle: item.title,
        prefillDate: item.completedAt ?? Date(),
        onSaved: { newEntryID in
          _ = store.setLinkedDiaryEntryID(item.id, entryID: newEntryID)
        }
      )
    }
  }

  private func linkedEntryExists(for item: ToDoItem) -> Bool {
    guard let entryID = item.linkedDiaryEntryID else { return false }
    return diaryStore.entryRecord(id: entryID) != nil
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
              Text(selectedSegment == .active ? "No dreams here yet." : "Nothing done here yet.")
                .font(.metadata)
                .foregroundStyle(Color("PlumForeground"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
              ForEach(items) { item in
                ToDoItemRow(
                  item: item,
                  isPendingCompletion: pendingCompletionIDs.contains(item.id),
                  status: selectedSegment.status,
                  hasLinkedMemory: linkedEntryExists(for: item),
                  onToggleComplete: {
                    toggle(item: item)
                  },
                  onWriteMemory: {
                    bridgingItem = item
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
              .fill(Color("RomanceBackground"))
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
      Image(systemName: selectedSegment == .active ? "sparkles" : "checkmark.circle")
        .font(.system(size: 36))
        .foregroundStyle(Color("PlumForeground"))
      Text(selectedSegment == .active ? "No dreams yet." : "Nothing done yet.")
        .font(.bodyEmphasis)
        .foregroundStyle(Color("PlumForeground"))
      Text(selectedSegment == .active ? "Tap + to dream up something together." : "Finish a dream and it lands here.")
        .font(.body)
        .foregroundStyle(Color("PlumForeground"))
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("RomanceBackground"))
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
        .font(.sectionHeader)
        .foregroundStyle(Color("RomanceForeground"))

      Spacer()

      if canManage {
        Menu {
          Button("Rename", systemImage: "pencil", action: onRename)
          Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 18))
            .foregroundStyle(Color("PlumForeground"))
        }
      }
    }
  }
}

private struct ToDoItemRow: View {
  let item: ToDoItem
  let isPendingCompletion: Bool
  let status: ToDoStatus
  let hasLinkedMemory: Bool
  let onToggleComplete: () -> Void
  let onWriteMemory: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggleComplete) {
        Image(systemName: iconName)
          .font(.system(size: 20))
          .foregroundStyle(item.status == .active ? Color("SageForeground") : Color("PlumForeground"))
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.body)
          .foregroundStyle(Color("RomanceForeground"))
          .strikethrough(status == .completed)
        if !item.details.isEmpty {
          Text(item.details)
            .font(.metadata)
            .foregroundStyle(Color("PlumForeground"))
            .lineLimit(2)
        }
        if status == .active, let targetDate = item.targetDate {
          metadataChip(icon: "calendar", text: targetDate.formatted(date: .abbreviated, time: .omitted))
        }
        if status == .completed {
          doneFooter
        }
      }

      Spacer(minLength: 8)

      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
          .font(.system(size: 16))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color("PlumForeground"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("SurfaceMuted"))
    )
  }

  /// Done rows show when the dream was finished and an optional invitation to
  /// write the moment down as a diary memory (or reopen the one already linked).
  private var doneFooter: some View {
    HStack(spacing: 8) {
      if let completedAt = item.completedAt {
        metadataChip(icon: "checkmark.seal", text: completedAt.formatted(date: .abbreviated, time: .omitted))
      }
      Button(action: onWriteMemory) {
        HStack(spacing: 4) {
          Image(systemName: hasLinkedMemory ? "book.closed" : "square.and.pencil")
          Text(hasLinkedMemory ? "View memory" : "Write it down")
        }
        .font(.metadata)
        .foregroundStyle(Color("RomanceForeground"))
      }
      .buttonStyle(.plain)
    }
    .padding(.top, 4)
  }

  private func metadataChip(icon: String, text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
      Text(text)
    }
    .font(.metadata)
    .foregroundStyle(Color("PlumForeground"))
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
  var store: ToDoStore

  @State private var title = ""
  @State private var details = ""
  @State private var selectedCategoryID: UUID = ToDoStore.uncategorizedCategoryID
  @State private var hasTargetDate = false
  @State private var targetDate = Date()
  @State private var showValidationError = false

  var body: some View {
    NavigationStack {
      Form {
        TextField("Dream title", text: $title)
          .font(.body)
        TextField("Notes (optional)", text: $details)
          .font(.body)
        Picker("Category", selection: $selectedCategoryID) {
          ForEach(store.categories) { category in
            Text(category.name).tag(category.id)
          }
        }
        .pickerStyle(.menu)
        Toggle("Set a date", isOn: $hasTargetDate)
          .font(.body)
        if hasTargetDate {
          DatePicker("When", selection: $targetDate, displayedComponents: [.date])
            .font(.body)
        }
      }
      .navigationTitle("New Idea")
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
            let added = store.addItem(
              title: title,
              details: details,
              categoryID: selectedCategoryID,
              targetDate: hasTargetDate ? targetDate : nil
            )
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
  var store: ToDoStore
  @State private var categoryName = ""
  @State private var showValidationError = false

  var body: some View {
    NavigationStack {
      Form {
        TextField("Category name", text: $categoryName)
          .font(.body)
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
  var store: ToDoStore
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
          .font(.body)
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

  func performDrop(info _: DropInfo) -> Bool {
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

  func performDrop(info _: DropInfo) -> Bool {
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
        targetDate: now.addingTimeInterval(7 * 86400),
        linkedDiaryEntryID: nil,
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
        targetDate: nil,
        linkedDiaryEntryID: nil,
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
