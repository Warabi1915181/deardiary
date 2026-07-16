import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DiaryView: View {
  var store: DiaryStore
  @State private var searchText = ""
  @State private var favoriteOnly = false
  @State private var showingEditor = false
  @FocusState private var isSearchFocused: Bool

  init(store: DiaryStore = DiaryStore()) {
    self.store = store
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Diary")
          .font(.screenTitle)
          .foregroundStyle(Color("RomanceForeground"))

        searchControls

        let entries = store.entries(matching: searchText, favoriteOnly: favoriteOnly)
        if entries.isEmpty {
          emptyState
        } else {
          VStack(spacing: 12) {
            ForEach(entries) { entry in
              NavigationLink {
                DiaryEntryDetailView(store: store, entryID: entry.id)
              } label: {
                DiaryEntryCard(entry: entry, store: store)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }
    .scrollDismissesKeyboard(.interactively)
    .simultaneousGesture(
      TapGesture().onEnded {
        isSearchFocused = false
      }
    )
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showingEditor = true
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color("RomanceForeground"))
        }
      }
    }
    .sheet(isPresented: $showingEditor) {
      DiaryEntryEditorView(store: store)
    }
  }

  private var searchControls: some View {
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(Color("PlumForeground"))
        TextField("Search memories, tags, or moods", text: $searchText)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($isSearchFocused)
      }
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color("RomanceBackground"))
      )

      Toggle("Favorites only", isOn: $favoriteOnly)
        .font(.body)
        .toggleStyle(.switch)
        .tint(Color("RomanceForeground"))
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "book.closed")
        .font(.system(size: 36))
        .foregroundStyle(Color("PlumForeground"))
      Text("No memories yet.")
        .font(.bodyEmphasis)
        .foregroundStyle(Color("PlumForeground"))
      Text("Start with today.")
        .font(.body)
        .foregroundStyle(Color("PlumForeground"))
      Button("Write a Memory") {
        showingEditor = true
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color("RomanceBackground"))
    )
  }
}

private struct DiaryEntryCard: View {
  let entry: DiaryEntry
  let store: DiaryStore

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
              .font(.metadata)
              .foregroundStyle(Color("PlumForeground"))
            Text(entry.title)
              .font(.entryTitle)
              .foregroundStyle(Color("RomanceForeground"))
          }
          Spacer()
          if entry.isFavorite {
            Image(systemName: "heart.fill")
              .foregroundStyle(Color("HeartRose"))
          }
        }

        if !entry.body.isEmpty {
          Text(entry.body)
            .font(.body)
            .foregroundStyle(Color("RomanceForeground"))
            .lineLimit(3)
        }

        if let firstPhoto = entry.photos.first {
          DiaryPhotoThumbnail(url: store.photoURL(for: firstPhoto), height: 160)
            .overlay(alignment: .bottomTrailing) {
              if entry.photos.count > 1 {
                Text("+\(entry.photos.count - 1)")
                  .font(.metadata)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(.thinMaterial, in: Capsule())
                  .padding(8)
              }
            }
        }

        DiaryEntryMetadataRow(entry: entry)
      }
    }
  }
}

private struct DiaryEntryDetailView: View {
  var store: DiaryStore
  let entryID: UUID
  @Environment(\.dismiss) private var dismiss
  @State private var showingEditor = false
  @State private var showingDeleteConfirmation = false

  private var entry: DiaryEntry? {
    store.entries.first(where: { $0.id == entryID })
  }

  var body: some View {
    ScrollView {
      if let entry {
        VStack(alignment: .leading, spacing: 16) {
          Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
            .font(.body)
            .foregroundStyle(Color("PlumForeground"))

          Text(entry.title)
            .font(.entryTitleLarge)
            .foregroundStyle(Color("RomanceForeground"))

          DiaryEntryMetadataRow(entry: entry)

          if entry.photos.count == 1, let photo = entry.photos.first {
            DiaryPhotoThumbnail(url: store.photoURL(for: photo), height: 220)
          } else if !entry.photos.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
              ForEach(entry.photos) { photo in
                DiaryPhotoThumbnail(url: store.photoURL(for: photo), height: 160)
              }
            }
          }

          Text(entry.body)
            .font(.bodyEmphasis)
            .foregroundStyle(Color("RomanceForeground"))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
      } else {
        Text("This memory is no longer available.")
          .font(.body)
          .foregroundStyle(Color("PlumForeground"))
          .padding(16)
      }
    }
    .background(Color("Backdrop").ignoresSafeArea())
    .navigationTitle("Memory")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let entry {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            _ = store.setFavorite(entry.id, isFavorite: !entry.isFavorite)
          } label: {
            Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
              .foregroundStyle(Color("HeartRose"))
          }

          Button("Edit") {
            showingEditor = true
          }

          Button(role: .destructive) {
            showingDeleteConfirmation = true
          } label: {
            Image(systemName: "trash")
          }
        }
      }
    }
    .sheet(isPresented: $showingEditor) {
      if let entry {
        DiaryEntryEditorView(store: store, entry: entry)
      }
    }
    .confirmationDialog("Delete this memory?", isPresented: $showingDeleteConfirmation) {
      Button("Delete Memory", role: .destructive) {
        if store.softDeleteEntry(id: entryID) {
          dismiss()
        }
      }
    }
  }
}

struct DiaryEntryEditorView: View {
  var store: DiaryStore
  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var bodyText: String
  @State private var entryDate: Date
  @State private var mood: DiaryMood?
  @State private var tagsText: String
  @State private var keptPhotos: [DiaryPhoto]
  @State private var selectedPhotoItems: [PhotosPickerItem] = []
  @State private var errorMessage: String?
  @State private var isSaving = false
  @FocusState private var focusedField: Field?

  private let entry: DiaryEntry?
  /// Fires with the new entry's id after a successful create, so a caller (e.g.
  /// the milestone memory bridge) can link the entry back to its source.
  private let onSaved: ((UUID) -> Void)?

  private enum Field: Hashable {
    case title
    case body
    case tags
  }

  init(
    store: DiaryStore,
    entry: DiaryEntry? = nil,
    prefillTitle: String = "",
    prefillBody: String = "",
    prefillDate: Date? = nil,
    onSaved: ((UUID) -> Void)? = nil
  ) {
    self.store = store
    self.entry = entry
    self.onSaved = onSaved
    _title = State(initialValue: entry?.title ?? prefillTitle)
    _bodyText = State(initialValue: entry?.body ?? prefillBody)
    _entryDate = State(initialValue: entry?.entryDate ?? prefillDate ?? Date())
    _mood = State(initialValue: entry?.mood)
    _tagsText = State(initialValue: entry?.tags.joined(separator: ", ") ?? "")
    _keptPhotos = State(initialValue: entry?.photos ?? [])
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Memory") {
          TextField("Title", text: $title)
            .focused($focusedField, equals: .title)
          DatePicker("Date", selection: $entryDate, displayedComponents: [.date])
          Picker("Mood", selection: $mood) {
            Text("None").tag(DiaryMood?.none)
            ForEach(DiaryMood.allCases) { mood in
              Text(mood.label).tag(Optional(mood))
            }
          }
          TextEditor(text: $bodyText)
            .frame(minHeight: 160)
            .focused($focusedField, equals: .body)
        }
        .listRowBackground(Color("Surface"))

        Section("Tags") {
          TextField("cozy, trip, dinner", text: $tagsText)
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .tags)
          if !store.allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(store.allTags, id: \.self) { tag in
                  Button(tag) {
                    appendTag(tag)
                  }
                  .buttonStyle(.bordered)
                }
              }
            }
          }
        }
        .listRowBackground(Color("Surface"))

        Section("Photos") {
          if !keptPhotos.isEmpty {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
              ForEach(Array(stride(from: 0, to: keptPhotos.count, by: 2)), id: \.self) { rowStart in
                GridRow {
                  ForEach(keptPhotos[rowStart ..< min(rowStart + 2, keptPhotos.count)]) { photo in
                    keptPhotoCell(photo)
                  }
                  if keptPhotos.count - rowStart == 1 {
                    Color.clear.gridCellUnsizedAxes(.vertical)
                  }
                }
              }
            }
          }

          PhotosPicker(
            selection: $selectedPhotoItems,
            matching: .images,
            photoLibrary: .shared()
          ) {
            Label("Add Photos", systemImage: "photo")
          }

          if !selectedPhotoItems.isEmpty {
            Text("\(selectedPhotoItems.count) new photo\(selectedPhotoItems.count == 1 ? "" : "s") selected")
              .font(.metadata)
              .foregroundStyle(Color("PlumForeground"))
          }
        }
        .listRowBackground(Color("Surface"))

        if let errorMessage {
          Section {
            Text(errorMessage)
              .font(.metadata)
              .foregroundStyle(.red)
          }
          .listRowBackground(Color("Surface"))
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color("Backdrop").ignoresSafeArea())
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(entry == nil ? "New Memory" : "Edit Memory")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving..." : "Save") {
            save()
          }
          .disabled(isSaving)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") {
            focusedField = nil
          }
        }
      }
    }
  }

  private func keptPhotoCell(_ photo: DiaryPhoto) -> some View {
    ZStack(alignment: .topTrailing) {
      DiaryPhotoThumbnail(url: store.photoURL(for: photo), height: 140)
      Button {
        keptPhotos.removeAll { $0.id == photo.id }
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(Color("RomanceForeground"))
          .background(Color("RomanceBackground"), in: Circle())
      }
      .buttonStyle(.borderless)
      .padding(8)
    }
  }

  private func appendTag(_ tag: String) {
    var tags = parsedTags
    guard !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else { return }
    tags.append(tag)
    tagsText = tags.joined(separator: ", ")
  }

  private var parsedTags: [String] {
    tagsText
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func save() {
    isSaving = true
    errorMessage = nil

    Task {
      do {
        let payloads = try await selectedPhotoItems.diaryPhotoPayloads()
        if let entry {
          _ = try store.updateEntry(
            id: entry.id,
            title: title,
            body: bodyText,
            entryDate: entryDate,
            mood: mood,
            tags: parsedTags,
            photosToKeep: keptPhotos,
            newPhotoPayloads: payloads
          )
        } else {
          if let newEntryID = try store.addEntry(
            title: title,
            body: bodyText,
            entryDate: entryDate,
            mood: mood,
            tags: parsedTags,
            photoPayloads: payloads
          ) {
            onSaved?(newEntryID)
          }
        }
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
      }
      isSaving = false
    }
  }
}

private struct DiaryEntryMetadataRow: View {
  let entry: DiaryEntry

  var body: some View {
    HStack(spacing: 8) {
      if let mood = entry.mood {
        Text(mood.label)
          .font(.metadata)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color("SageBackground"), in: Capsule())
          .foregroundStyle(Color("SageForeground"))
      }

      ForEach(entry.tags, id: \.self) { tag in
        Text("#\(tag)")
          .font(.metadata)
          .foregroundStyle(Color("PlumForeground"))
      }
    }
  }
}

private struct DiaryPhotoThumbnail: View {
  let url: URL
  let height: CGFloat

  var body: some View {
    Group {
      if let image = UIImage(contentsOfFile: url.path) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          Color("SurfaceMuted")
          Image(systemName: "photo")
            .foregroundStyle(Color("PlumForeground"))
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .contentShape(RoundedRectangle(cornerRadius: 16))
  }
}

private extension Array where Element == PhotosPickerItem {
  func diaryPhotoPayloads() async throws -> [DiaryPhotoPayload] {
    var payloads: [DiaryPhotoPayload] = []
    for item in self {
      guard let data = try await item.loadTransferable(type: Data.self) else { continue }
      let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
      payloads.append(DiaryPhotoPayload(data: data, fileExtension: fileExtension))
    }
    return payloads
  }
}

#Preview {
  NavigationStack {
    DiaryView()
  }
}
