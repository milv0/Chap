import Foundation
import Testing

@testable import Chap

@Suite("TodoStore – notch to-do list")
struct TodoStoreTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("titles are trimmed to one line, capped, and empty ones are refused")
    func cleanedTitle() {
        #expect(TodoStore.cleanedTitle("  Buy milk \n") == "Buy milk")
        #expect(TodoStore.cleanedTitle("two\nlines") == "two lines")
        #expect(TodoStore.cleanedTitle("   \n ") == nil)
        let long = String(repeating: "a", count: TodoStore.maxTitleLength + 50)
        #expect(TodoStore.cleanedTitle(long)?.count == TodoStore.maxTitleLength)
    }

    @Test("adding appends, ignores blanks, and stops at four items")
    func adding() {
        var items: [TodoItem] = []
        items = TodoStore.adding("One", to: items, now: start)
        items = TodoStore.adding("  ", to: items, now: start)
        #expect(items.map(\.title) == ["One"])
        for index in 0..<10 {
            items = TodoStore.adding("Item \(index)", to: items, now: start)
        }
        #expect(TodoStore.maxItems == 4)
        #expect(items.count == 4)
        #expect(!TodoStore.canAdd(items))
        // 완료 항목을 지우면 다시 더할 수 있다.
        let done = TodoStore.toggling(items[0].id, in: items)
        #expect(TodoStore.canAdd(TodoStore.clearingCompleted(done)))
    }

    @Test("toggling marks done with a time and back again")
    func toggling() throws {
        let items = TodoStore.adding("Ship it", to: [], now: start)
        let id = try #require(items.first?.id)
        let done = TodoStore.toggling(id, in: items, now: start.addingTimeInterval(60))
        #expect(done.first?.isDone == true)
        #expect(done.first?.completed == start.addingTimeInterval(60))
        let undone = TodoStore.toggling(id, in: done)
        #expect(undone.first?.isDone == false && undone.first?.completed == nil)
    }

    @Test("finished items stay where they are, in the order they were added")
    func ordered() {
        let a = TodoItem(title: "A", created: start)
        let b = TodoItem(title: "B", created: start.addingTimeInterval(1))
        let c = TodoItem(title: "C", created: start.addingTimeInterval(2))
        var items = [a, b, c]
        items = TodoStore.toggling(a.id, in: items, now: start.addingTimeInterval(20))
        items = TodoStore.toggling(c.id, in: items, now: start.addingTimeInterval(10))
        #expect(items.map(\.title) == ["A", "B", "C"])
        #expect(TodoStore.ordered(items).map(\.title) == ["A", "B", "C"])
        #expect(TodoStore.ordered([c, a, b]).map(\.title) == ["A", "B", "C"])
    }

    @Test("renaming to blank deletes; clearing completed keeps open items")
    func renameAndClear() throws {
        var items = TodoStore.adding("Draft", to: [], now: start)
        items = TodoStore.adding("Keep", to: items, now: start)
        let draft = try #require(items.first?.id)
        #expect(TodoStore.renaming(draft, to: "Final", in: items).first?.title == "Final")
        #expect(TodoStore.renaming(draft, to: "  ", in: items).map(\.title) == ["Keep"])
        let toggled = TodoStore.toggling(draft, in: items)
        #expect(TodoStore.clearingCompleted(toggled).map(\.title) == ["Keep"])
        #expect(TodoStore.remainingLabel(toggled) == "1")
        #expect(
            TodoStore.remainingLabel(
                TodoStore.clearingCompleted(toggled).map { item in
                    var item = item
                    item.isDone = true
                    return item
                }) == nil)
    }

    @Test("progress fills with finished items and all-done needs at least one item")
    func progressAndAllDone() {
        #expect(TodoStore.progress([]) == nil)
        #expect(!TodoStore.isAllDone([]))
        var items = TodoStore.adding("A", to: [], now: start)
        items = TodoStore.adding("B", to: items, now: start)
        #expect(TodoStore.progress(items) == 0)
        items = TodoStore.toggling(items[0].id, in: items)
        #expect(TodoStore.progress(items) == 0.5)
        #expect(!TodoStore.isAllDone(items))
        items = TodoStore.toggling(items[1].id, in: items)
        #expect(TodoStore.progress(items) == 1)
        #expect(TodoStore.isAllDone(items))
    }

    @Test("undo puts cleared items back in their place without dropping new ones")
    func restoreCleared() {
        let a = TodoItem(title: "A", created: start)
        let b = TodoItem(title: "B", created: start.addingTimeInterval(1))
        let c = TodoItem(title: "C", created: start.addingTimeInterval(2))
        var items = [a, b, c]
        items = TodoStore.toggling(a.id, in: items)
        items = TodoStore.toggling(c.id, in: items)
        let cleared = items.filter(\.isDone)
        var left = TodoStore.clearingCompleted(items)
        #expect(left.map(\.title) == ["B"])
        #expect(TodoStore.restoring(cleared, into: left).map(\.title) == ["A", "B", "C"])
        // 그사이 새로 넣은 항목은 지키고, 한도를 넘는 만큼은 되돌리지 않는다.
        left = TodoStore.adding("D", to: left, now: start.addingTimeInterval(9))
        left = TodoStore.adding("E", to: left, now: start.addingTimeInterval(10))
        let restored = TodoStore.restoring(cleared, into: left)
        #expect(restored.count == TodoStore.maxItems)
        #expect(restored.map(\.title) == ["A", "B", "D", "E"])
        // 이미 있는 항목은 두 번 넣지 않는다.
        #expect(TodoStore.restoring(cleared, into: items).map(\.title) == ["A", "B", "C"])
    }

    @Test("the list round-trips through its file and a missing file is empty")
    func persistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapTodoTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TodoStore(fileURL: directory.appendingPathComponent("Todos.json"))
        #expect(store.load().isEmpty)

        var items = TodoStore.adding("Persist me", to: [], now: start)
        items = TodoStore.toggling(items[0].id, in: items, now: start)
        try store.save(items)

        let loaded = store.load()
        #expect(loaded.map(\.title) == ["Persist me"])
        #expect(loaded.first?.isDone == true)
        #expect(loaded.first?.id == items.first?.id)
    }

    @Test("To-do is a placeable widget slot that older versions can skip")
    func widgetSlot() throws {
        #expect(NotchWidget.todo.fits(slot: 2) && !NotchWidget.todo.fits(slot: 0))
        let config = try JSONDecoder().decode(
            Config.self,
            from: Data(#"{"notchWidgets": ["none", "none", "todo"], "sites": []}"#.utf8))
        #expect(config.notchWidgets == [.none, .none, .todo, .none, .none, .none])
    }
}
