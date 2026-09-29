import Testing

@testable import Chap

@Suite("ChapMascot – pixel sprite")
struct ChapMascotTests {
    @Test("every row is exactly 24 columns and there are 12 rows")
    func gridShape() {
        #expect(ChapMascot.rows.count == 12)
        #expect(ChapMascot.rows.allSatisfy { $0.count == 24 })
        #expect(ChapMascot.width == 24)
        #expect(ChapMascot.height == 12)
    }

    @Test("the grid uses only the four known symbols")
    func knownSymbols() {
        let allowed: Set<Character> = [".", "o", "w", "s", "e"]
        #expect(ChapMascot.rows.allSatisfy { $0.allSatisfy(allowed.contains) })
    }

    @Test("the seal has two eyes on the same row")
    func twoEyes() {
        let eyes = ChapMascot.rows.enumerated().flatMap { y, row in
            row.enumerated().filter { $0.element == "e" }.map { _ in y }
        }
        #expect(eyes == [4, 4])
    }

    @Test("pixels skip transparent cells and stay inside the grid")
    func pixelsInBounds() {
        #expect(!ChapMascot.pixels.isEmpty)
        #expect(ChapMascot.pixels.allSatisfy { (0..<24).contains($0.x) && (0..<12).contains($0.y) })
        #expect(ChapMascot.pixels.contains { $0.ink == .body })
        #expect(ChapMascot.pixels.contains { $0.ink == .shade })
    }

    @Test("the tail-up frame matches the grid and only changes the tail")
    func tailUpFrame() {
        #expect(ChapMascot.tailUpRows.count == 12)
        #expect(ChapMascot.tailUpRows.allSatisfy { $0.count == 24 })
        for (rest, up) in zip(ChapMascot.rows, ChapMascot.tailUpRows) {
            // 머리와 몸통(왼쪽 19칸)은 두 프레임이 같다.
            #expect(rest.prefix(19) == up.prefix(19))
        }
        #expect(ChapMascot.rows != ChapMascot.tailUpRows)
        #expect(ChapMascot.pixels(for: .rest) == ChapMascot.pixels)
        #expect(ChapMascot.pixels(for: .tailUp) == ChapMascot.tailUpPixels)
    }

    @Test("a flick lifts the tail twice and ends at rest")
    func flickSequence() {
        #expect(ChapMascot.flickSequence == [.tailUp, .rest, .tailUp, .rest])
        #expect(ChapMascot.flickSequence.last == .rest)
    }

    @Test("idle flicks stay rare and quick")
    func flickTiming() {
        #expect(ChapMascot.idleFlickInterval.lowerBound >= 5)
        #expect(ChapMascot.flickFrameDuration <= 0.2)
    }

    @Test("the strip size lands on whole Retina pixels")
    func stripSizeIsCrisp() {
        #expect(ChapMascot.stripPixelSize * 2 == 3)
    }
}
