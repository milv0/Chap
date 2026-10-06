import Foundation
import Testing

@testable import Chap

@Suite("DropStore – original references")
struct DropStoreTests {
    /// 임시 폴더 안에 보관함과 "사용자 파일" 폴더를 만든다. 참조 규칙을 시험하려고 임시 위치 사본 규칙은
    /// 따로 지정한 폴더(`temp`)에만 적용한다.
    private func makeFixture() throws -> (store: DropStore, files: URL, temp: URL, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapDropStoreTests-\(UUID().uuidString)", isDirectory: true)
        let folder = root.appendingPathComponent("Drop", isDirectory: true)
        let files = root.appendingPathComponent("Documents", isDirectory: true)
        let temp = root.appendingPathComponent("Scratch", isDirectory: true)
        for dir in [folder, files, temp] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let store = DropStore(
            folder: folder, copyPrefixes: [temp.resolvingSymlinksInPath().path + "/"])
        return (store, files, temp, root)
    }

    private func write(_ name: String, in dir: URL, _ text: String = "hello") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    @Test("a dropped file is kept by reference, not copied")
    func keepsReference() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let original = try write("Report.pdf", in: f.files)

        let result = f.store.add([original])

        #expect(result.failed == 0)
        let entries = f.store.entries()
        #expect(entries.count == 1 && entries[0].isReference)
        #expect(
            entries[0].url.resolvingSymlinksInPath().path == original.resolvingSymlinksInPath().path
        )
        // 보관함 폴더에는 숨김 목록 파일 말고 아무 사본도 없다.
        let copies = try FileManager.default.contentsOfDirectory(
            atPath: f.store.folder.path
        ).filter { !$0.hasPrefix(".") }
        #expect(copies.isEmpty)
    }

    @Test("the reference follows a renamed or moved original")
    func followsMove() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let original = try write("Draft.txt", in: f.files)
        f.store.add([original])

        let moved = f.root.appendingPathComponent("Final.txt")
        try FileManager.default.moveItem(at: original, to: moved)

        let entries = f.store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.url.lastPathComponent == "Final.txt")
    }

    @Test("deleting the original drops it from Chap Drop")
    func deletedOriginalDisappears() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let original = try write("Gone.txt", in: f.files)
        f.store.add([original])

        try FileManager.default.removeItem(at: original)

        #expect(f.store.entries().isEmpty)
    }

    @Test("removing a reference never touches the original file")
    func removeKeepsOriginal() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let original = try write("Keep.txt", in: f.files, "precious")
        f.store.add([original])

        #expect(f.store.remove(original))

        #expect(f.store.entries().isEmpty)
        #expect(try String(contentsOf: original, encoding: .utf8) == "precious")
    }

    @Test("files from a temporary location are copied so they outlive the temp folder")
    func tempFilesAreCopied() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let temp = try write("clip.png", in: f.temp)

        let result = f.store.add([temp])
        try FileManager.default.removeItem(at: temp)

        let entries = f.store.entries()
        #expect(result.failed == 0)
        #expect(entries.count == 1 && !entries[0].isReference)
        #expect(f.store.isOwnedCopy(entries[0].url))
        // Chap 사본은 지우면 실제로 삭제된다.
        #expect(f.store.remove(entries[0].url))
        #expect(!FileManager.default.fileExists(atPath: entries[0].url.path))
    }

    @Test("copies kept by earlier versions still show and can be removed")
    func legacyCopiesStay() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let legacy = try write("Old copy.pptx", in: f.store.folder)

        let entries = f.store.entries()
        #expect(entries.map(\.url.lastPathComponent) == ["Old copy.pptx"])
        #expect(entries.first?.isReference == false)
        #expect(f.store.remove(legacy))
    }

    @Test("dropping the same file again moves it to the front without duplicating")
    func dedupes() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let a = try write("A.txt", in: f.files)
        let b = try write("B.txt", in: f.files)
        let start = Date(timeIntervalSince1970: 1_000_000)
        f.store.add([a], now: start)
        f.store.add([b], now: start.addingTimeInterval(10))
        f.store.add([a], now: start.addingTimeInterval(20))

        #expect(f.store.entries().map(\.url.lastPathComponent) == ["A.txt", "B.txt"])
    }
}
