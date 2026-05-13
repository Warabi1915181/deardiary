import Foundation
import Testing
@testable import Dear_Diary

@MainActor
struct DiaryStoreTests {
  @Test func addEntryPersistsAndReloads() throws {
    let fixture = try DiaryStoreFixture()
    let store = DiaryStore(
      storeURL: fixture.storeURL,
      photosDirectoryURL: fixture.photosURL,
      deviceID: "test-device"
    )
    let entryDate = Date(timeIntervalSince1970: 1_800)

    let id = try store.addEntry(
      title: " First date ",
      body: " Dinner and a walk ",
      entryDate: entryDate,
      mood: .happy,
      tags: [" date ", "Date", "walk"],
      photoPayloads: []
    )

    #expect(id != nil)
    #expect(store.entries.count == 1)
    #expect(store.entries[0].title == "First date")
    #expect(store.entries[0].body == "Dinner and a walk")
    #expect(store.entries[0].tags == ["date", "walk"])
    #expect(store.entries[0].mood == .happy)
    #expect(store.entries[0].modifiedByDeviceID == "test-device")

    let reloaded = DiaryStore(
      storeURL: fixture.storeURL,
      photosDirectoryURL: fixture.photosURL,
      deviceID: "test-device"
    )
    #expect(reloaded.entries.count == 1)
    #expect(reloaded.entries[0].id == id)
  }

  @Test func searchMatchesBodyTagsMoodAndFavorites() throws {
    let fixture = try DiaryStoreFixture()
    let store = DiaryStore(
      storeURL: fixture.storeURL,
      photosDirectoryURL: fixture.photosURL,
      deviceID: "test-device"
    )

    let cozyID = try #require(try store.addEntry(
      title: "Rainy morning",
      body: "Coffee at home",
      entryDate: Date(timeIntervalSince1970: 1_000),
      mood: .cozy,
      tags: ["home"],
      photoPayloads: []
    ))
    _ = try store.addEntry(
      title: "Dinner",
      body: "Noodles downtown",
      entryDate: Date(timeIntervalSince1970: 900),
      mood: .happy,
      tags: ["food"],
      photoPayloads: []
    )
    _ = store.setFavorite(cozyID, isFavorite: true)

    #expect(store.entries(matching: "coffee").map(\.id) == [cozyID])
    #expect(store.entries(matching: "home").map(\.id) == [cozyID])
    #expect(store.entries(matching: "cozy").map(\.id) == [cozyID])
    #expect(store.entries(matching: "", favoriteOnly: true).map(\.id) == [cozyID])
  }

  @Test func softDeleteHidesEntryButKeepsState() throws {
    let fixture = try DiaryStoreFixture()
    let store = DiaryStore(
      storeURL: fixture.storeURL,
      photosDirectoryURL: fixture.photosURL,
      deviceID: "test-device"
    )
    let id = try #require(try store.addEntry(
      title: "Memory",
      body: "Body",
      entryDate: Date(),
      mood: nil,
      tags: [],
      photoPayloads: []
    ))

    #expect(store.softDeleteEntry(id: id))
    #expect(store.entries.isEmpty)
    #expect(store.state.entries.first?.deletedAt != nil)
  }

  @Test func photoFilesAreSavedAndRemovedOnUpdate() throws {
    let fixture = try DiaryStoreFixture()
    let store = DiaryStore(
      storeURL: fixture.storeURL,
      photosDirectoryURL: fixture.photosURL,
      deviceID: "test-device"
    )
    let id = try #require(try store.addEntry(
      title: "Photo memory",
      body: "Two photos",
      entryDate: Date(),
      mood: nil,
      tags: [],
      photoPayloads: [
        DiaryPhotoPayload(data: Data([1, 2, 3]), fileExtension: "jpg"),
        DiaryPhotoPayload(data: Data([4, 5, 6]), fileExtension: "png"),
      ]
    ))

    let entry = try #require(store.entries.first(where: { $0.id == id }))
    #expect(entry.photos.count == 2)
    let removedPhoto = entry.photos[0]
    let keptPhoto = entry.photos[1]
    #expect(FileManager.default.fileExists(atPath: store.photoURL(for: removedPhoto).path))
    #expect(FileManager.default.fileExists(atPath: store.photoURL(for: keptPhoto).path))

    #expect(try store.updateEntry(
      id: id,
      title: entry.title,
      body: entry.body,
      entryDate: entry.entryDate,
      mood: entry.mood,
      tags: entry.tags,
      photosToKeep: [keptPhoto],
      newPhotoPayloads: []
    ))

    #expect(!FileManager.default.fileExists(atPath: store.photoURL(for: removedPhoto).path))
    #expect(FileManager.default.fileExists(atPath: store.photoURL(for: keptPhoto).path))
  }
}

private struct DiaryStoreFixture {
  let rootURL: URL
  let storeURL: URL
  let photosURL: URL

  init() throws {
    rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    storeURL = rootURL.appendingPathComponent("diary.store.v1.json")
    photosURL = rootURL.appendingPathComponent("DiaryPhotos", isDirectory: true)
  }
}
