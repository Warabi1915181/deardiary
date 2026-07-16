import SwiftUI

/// Curated, romance/celebration-appropriate icon choices for a milestone.
/// Kept small and hand-picked rather than exposing the full SF Symbols catalog.
private let milestoneIconOptions = [
  "heart.fill", "star.fill", "gift.fill", "calendar", "sparkles",
  "birthday.cake.fill", "airplane", "house.fill",
]

struct MilestonesView: View {
  var store: MilestoneStore
  @State private var showingEditor = false
  @State private var editingMilestone: Milestone?

  init(store: MilestoneStore) {
    self.store = store
  }

  var body: some View {
    content
      .background(Color("Backdrop").ignoresSafeArea())
      .navigationTitle("Milestones")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        addButton
      }
      .sheet(isPresented: $showingEditor) {
        MilestoneEditorView(store: store)
      }
      .sheet(item: $editingMilestone) { milestone in
        MilestoneEditorView(store: store, milestone: milestone)
      }
  }

  @ViewBuilder
  private var content: some View {
    if store.milestones.isEmpty {
      ScrollView {
        emptyState
          .padding(.horizontal, 16)
          .padding(.top, 16)
      }
    } else {
      milestoneList
    }
  }

  private var milestoneList: some View {
    List {
      ForEach(store.milestones) { milestone in
        milestoneRow(for: milestone)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }

  private func milestoneRow(for milestone: Milestone) -> some View {
    Button {
      editingMilestone = milestone
    } label: {
      MilestoneRow(milestone: milestone, store: store)
    }
    .buttonStyle(.plain)
    .listRowBackground(Color.clear as Color)
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        withAnimation(.easeInOut(duration: 0.2)) {
          _ = store.softDeleteMilestone(id: milestone.id)
        }
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  @ToolbarContentBuilder
  private var addButton: some ToolbarContent {
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

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "sparkles")
        .font(.system(size: 36))
        .foregroundStyle(Color("PlumForeground"))
      Text("No milestones yet.")
        .font(.bodyEmphasis)
        .foregroundStyle(Color("PlumForeground"))
      Text("Add the moments worth remembering.")
        .font(.body)
        .foregroundStyle(Color("PlumForeground"))
      Button("Add a Milestone") {
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
    .padding(.horizontal, 16)
    .padding(.top, 16)
  }
}

private struct MilestoneRow: View {
  let milestone: Milestone
  let store: MilestoneStore

  private var isYearly: Bool { milestone.recurrence == .yearly }

  private var nextOccurrence: Date {
    store.nextOccurrence(of: milestone)
  }

  private var isHeart: Bool {
    milestone.icon.hasPrefix("heart")
  }

  var body: some View {
    Card(verticalPadding: 16) {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          Circle()
            .fill(Color("RomanceBackground"))
            .frame(width: 40, height: 40)
          Image(systemName: milestone.icon)
            .font(.system(size: 18))
            // Heart glyphs keep the Heart Rose jewel color; every other
            // milestone icon rides the Romance Accent like the rest of the app.
            .foregroundStyle(isHeart ? Color("HeartRose") : Color("RomanceForeground"))
        }

        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(milestone.title)
              .font(.cardTitle)
              .foregroundStyle(Color("RomanceForeground"))
            if isYearly {
              Text(MilestoneRecurrence.yearly.label)
                .font(.metadata)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color("PlumBackground"), in: Capsule())
                .foregroundStyle(Color("PlumForeground"))
            }
          }

          Text(dateLine)
            .font(.metadata)
            .foregroundStyle(Color("InkMuted"))

          if !milestone.note.isEmpty {
            Text(milestone.note)
              .font(.body)
              .foregroundStyle(Color("RomanceForeground"))
              .lineLimit(2)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var dateLine: String {
    let formattedDate = milestone.date.formatted(date: .abbreviated, time: .omitted)
    guard isYearly else { return formattedDate }
    let formattedNext = nextOccurrence.formatted(date: .abbreviated, time: .omitted)
    return "\(formattedDate) · Next: \(formattedNext)"
  }
}

struct MilestoneEditorView: View {
  var store: MilestoneStore
  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var date: Date
  @State private var recurrence: MilestoneRecurrence
  @State private var icon: String
  @State private var note: String
  @State private var showValidationError = false
  @FocusState private var focusedField: Field?

  private let milestone: Milestone?

  private enum Field: Hashable {
    case title
    case note
  }

  init(store: MilestoneStore, milestone: Milestone? = nil) {
    self.store = store
    self.milestone = milestone
    _title = State(initialValue: milestone?.title ?? "")
    _date = State(initialValue: milestone?.date ?? Date())
    _recurrence = State(initialValue: milestone?.recurrence ?? .none)
    _icon = State(initialValue: milestone?.icon ?? milestoneIconOptions[0])
    _note = State(initialValue: milestone?.note ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Milestone") {
          TextField("Title", text: $title)
            .focused($focusedField, equals: .title)
          DatePicker("Date", selection: $date, displayedComponents: [.date])
          Picker("Repeats", selection: $recurrence) {
            ForEach(MilestoneRecurrence.allCases) { option in
              Text(option.label).tag(option)
            }
          }
        }
        .listRowBackground(Color("Surface"))

        Section("Icon") {
          iconPicker
        }
        .listRowBackground(Color("Surface"))

        Section("Note") {
          TextEditor(text: $note)
            .frame(minHeight: 100)
            .focused($focusedField, equals: .note)
        }
        .listRowBackground(Color("Surface"))
      }
      .scrollContentBackground(.hidden)
      .background(Color("Backdrop").ignoresSafeArea())
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(milestone == nil ? "New Milestone" : "Edit Milestone")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            save()
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") {
            focusedField = nil
          }
        }
      }
      .alert("Title required", isPresented: $showValidationError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Please enter a title for this milestone.")
      }
    }
  }

  private var iconPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(milestoneIconOptions, id: \.self) { option in
          Button {
            icon = option
          } label: {
            Image(systemName: option)
              .font(.system(size: 20))
              .frame(width: 44, height: 44)
              .foregroundStyle(
                // Heart Rose is glyph-only and applies wherever the heart
                // appears, regardless of selection state.
                option.hasPrefix("heart")
                  ? Color("HeartRose")
                  : (option == icon ? Color("RomanceForeground") : Color("PlumForeground"))
              )
              .background(
                Circle()
                  .fill(option == icon ? Color("RomanceBackground") : Color("SurfaceMuted"))
              )
              .overlay(
                Circle()
                  .strokeBorder(Color("RomanceForeground").opacity(option == icon ? 0.4 : 0), lineWidth: 2)
              )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func save() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      showValidationError = true
      return
    }

    if let milestone {
      _ = store.updateMilestone(
        id: milestone.id,
        title: title,
        date: date,
        note: note,
        recurrence: recurrence,
        icon: icon
      )
    } else {
      _ = store.addMilestone(
        title: title,
        date: date,
        note: note,
        recurrence: recurrence,
        icon: icon
      )
    }
    dismiss()
  }
}

#Preview {
  NavigationStack {
    MilestonesView(store: MilestoneStore())
  }
}
