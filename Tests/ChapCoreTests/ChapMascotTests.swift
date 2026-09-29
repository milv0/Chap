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

@Suite("ChapMascot – Focus moods")
struct ChapMascotFocusMoodTests {
    @Test("mood follows the Keep Awake session")
    func moodFromRemaining() {
        #expect(ChapMascot.focusMood(remaining: nil) == .asleep)
        #expect(ChapMascot.focusMood(remaining: 0) == .asleep)
        #expect(ChapMascot.focusMood(remaining: 60) == .drowsy)
        #expect(ChapMascot.focusMood(remaining: 1799) == .drowsy)
        #expect(ChapMascot.focusMood(remaining: 1800) == .awake)
        #expect(ChapMascot.focusMood(remaining: 8 * 3600) == .awake)
    }

    @Test("the drowsy boundary matches the Final stretch line")
    func drowsyMatchesCopy() {
        #expect(KeepAwakePolicy.focusActiveLine(remaining: 1799) == "Final stretch")
        #expect(ChapMascot.focusMood(remaining: 1799) == .drowsy)
        #expect(KeepAwakePolicy.focusActiveLine(remaining: 1800) == "In the zone")
        #expect(ChapMascot.focusMood(remaining: 1800) == .awake)
    }

    @Test("each mood has its own eyes")
    func moodEyes() {
        #expect(ChapMascot.FocusMood.asleep.eyes == .closed)
        #expect(ChapMascot.FocusMood.awake.eyes == .open)
        #expect(ChapMascot.FocusMood.drowsy.eyes == .drowsy)
    }

    @Test("eye variants only touch the face and keep the grid shape")
    func eyeVariants() {
        for eyes in [ChapMascot.Eyes.closed, .drowsy] {
            for pose in [ChapMascot.Pose.rest, .tailUp] {
                let grid = ChapMascot.rows(eyes: eyes, pose: pose)
                let base = pose == .rest ? ChapMascot.rows : ChapMascot.tailUpRows
                #expect(grid.count == 12)
                #expect(grid.allSatisfy { $0.count == 24 })
                #expect(grid != base)
                // 얼굴(3~4행, 4~8열) 밖은 그대로다.
                for (y, (a, b)) in zip(grid, base).enumerated() {
                    for (x, (ca, cb)) in zip(a, b).enumerated() where ca != cb {
                        #expect((3...4).contains(y) && (4...8).contains(x))
                    }
                }
            }
        }
        #expect(ChapMascot.pixels(eyes: .open, pose: .rest) == ChapMascot.pixels)
    }

    @Test("closed eyes have no open-eye dots left")
    func closedEyes() {
        let row = Array(ChapMascot.rows(eyes: .closed, pose: .rest)[4])
        #expect(row[4] == "e" && row[5] == "e" && row[7] == "e" && row[8] == "e")
        #expect(row[6] == "w")
    }

    @Test("the z is a 4x4 zig-zag and the widget size lands on Retina pixels")
    func zAndSize() {
        #expect(ChapMascot.sleepZRows == ["oooo", "..o.", ".o..", "oooo"])
        #expect(ChapMascot.widgetPixelSize * 2 == 4)
        #expect(ChapMascot.blinkDuration < 0.3)
        #expect(ChapMascot.sleepZRiseDuration < ChapMascot.sleepZPeriod)
    }
}
