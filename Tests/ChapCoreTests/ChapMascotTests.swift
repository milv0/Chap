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

    @Test("the tail wags while Focus runs, slower when drowsy, never asleep")
    func focusWag() {
        #expect(ChapMascot.focusWagFrameDuration(for: .asleep) == nil)
        #expect(ChapMascot.focusWagFrameDuration(for: .awake) == 0.4)
        #expect(ChapMascot.focusWagFrameDuration(for: .drowsy) == 0.7)
    }

    @Test("the z is a 4x4 zig-zag and the widget size lands on Retina pixels")
    func zAndSize() {
        #expect(ChapMascot.sleepZRows == ["oooo", "..o.", ".o..", "oooo"])
        #expect(ChapMascot.widgetPixelSize * 2 == 4)
        #expect(ChapMascot.blinkDuration < 0.3)
        #expect(ChapMascot.sleepZRiseDuration < ChapMascot.sleepZPeriod)
    }
}

@Suite("ChapMascot – Focus dive")
struct ChapMascotFocusDiveTests {
    @Test("the dive water stays below the face")
    func waterLevel() {
        let full = ChapMascot.waterPixels(level: ChapMascot.waterLevel, phase: 0)
        #expect(full.allSatisfy { ChapMascot.waterSpan.contains($0.x) })
        #expect(full.filter { $0.ink == .crest }.allSatisfy { $0.y == 9 || $0.y == 10 })
        #expect(full.map(\.y).max() == ChapMascot.waterBottom)
        #expect(full.allSatisfy { $0.y > 4 })
    }

    @Test("the waves move one cell per phase and repeat every four")
    func wavesFlow() {
        let a = ChapMascot.waterPixels(level: 9, phase: 0)
        #expect(a != ChapMascot.waterPixels(level: 9, phase: 1))
        #expect(ChapMascot.waterPixels(level: 9, phase: 4) == a)
    }

    @Test("the dive hops, splashes in, pops back up, and ends dry in about a second")
    func diveSequence() {
        let steps = ChapMascot.focusDiveSequence
        #expect(steps.first?.offsetY == 1 && steps.first?.waterLevel == nil)
        #expect(steps.contains { $0.offsetY < 0 && $0.pose == .tailUp && $0.waterLevel == nil })
        #expect(steps.contains { $0.offsetY > 0 && $0.waterLevel != nil })
        #expect(steps.filter { !$0.splash.isEmpty }.count >= 3)
        // 끝은 물 없이 원래 자리: 잠수하거나 헤엄치지 않는다.
        #expect(steps.last?.offsetY == 0 && steps.last?.waterLevel == nil)
        #expect(steps.last?.splash.isEmpty == true)
        let total = Double(steps.count) * ChapMascot.focusDiveFrameDuration
        #expect(total > 0.6 && total <= 1.0)
    }
}

@Suite("ChapMascot – menu bar outline")
struct ChapMascotMenuBarTests {
    @Test("the outline draws the lines, eyes, and mouth, and leaves the body empty")
    func outlineOnly() {
        let cells = Set(ChapMascot.menuBarOutline.map { [$0.x, $0.y] })
        // 눈과 입은 칠한다.
        #expect(cells.contains([4, 4]) && cells.contains([7, 4]))
        #expect(cells.contains([5, 6]) && cells.contains([6, 6]))
        // 이마와 몸통(흰 칸), 배 그림자는 비운다.
        #expect(!cells.contains([5, 4]) && !cells.contains([12, 6]))
        #expect(!cells.contains([1, 8]))
        let lines = ChapMascot.rows.joined().filter { $0 == "o" || $0 == "e" }.count
        #expect(cells.count == lines)
    }

    @Test("the face cells are the eyes and mouth, and are part of the outline")
    func faceCells() {
        let outline = Set(ChapMascot.menuBarOutline.map { [$0.x, $0.y] })
        #expect(ChapMascot.menuBarFace.isSubset(of: outline))
        let eyes = ChapMascot.rows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, ch in ch == "e" ? [x, y] : nil }
        }
        #expect(Set(eyes).isSubset(of: ChapMascot.menuBarFace))
    }

    @Test("the outline fits the 28pt status item at one point per cell")
    func fitsStatusItem() {
        #expect(ChapMascot.menuBarOutline.allSatisfy { (0..<24).contains($0.x) })
        #expect(ChapMascot.menuBarOutline.allSatisfy { (0..<12).contains($0.y) })
    }

    @Test("a dreaming seal flicks once, and less often than an awake one")
    func dreamFlick() {
        #expect(ChapMascot.dreamFlickSequence == [.tailUp, .rest])
        #expect(ChapMascot.dreamFlickInterval.lowerBound > ChapMascot.idleFlickInterval.lowerBound)
    }
}

@Suite("ChapMascot – swimming on extra screens")
struct ChapMascotSwimTests {
    @Test("the seal enters from the right and swims left at a steady pace")
    func swimsLeft() {
        let start = ChapMascot.swimFrame(elapsed: 0, laneCells: 200)
        #expect(start.x == 200)  // 오른쪽 끝 바로 밖
        let later = ChapMascot.swimFrame(elapsed: 10, laneCells: 200)
        #expect(later.x == 200 - Int(10 * ChapMascot.Swim.speed))
    }

    @Test("after leaving the left edge it comes back from the right")
    func wrapsAround() {
        let lane = 100
        let loop = Double(lane + ChapMascot.width) / ChapMascot.Swim.speed
        #expect(ChapMascot.swimFrame(elapsed: loop, laneCells: lane).x == lane)
        // 거의 한 바퀴 돌았을 때는 왼쪽 밖에 있다(스프라이트 폭만큼).
        let nearlyOut = ChapMascot.swimFrame(elapsed: loop - 0.01, laneCells: lane)
        #expect(nearlyOut.x <= -ChapMascot.width + 1)
    }

    @Test("it bobs one cell and paddles with its tail")
    func bobsAndPaddles() {
        let bobs = Set(
            (0..<20).map { ChapMascot.swimFrame(elapsed: Double($0) * 0.5, laneCells: 100).bob })
        #expect(bobs == [0, 1])
        let poses = Set(
            (0..<10).map { ChapMascot.swimFrame(elapsed: Double($0) * 0.15, laneCells: 100).pose })
        #expect(poses == [.rest, .tailUp])
    }

    @Test("screens start at different places")
    func offsetsDiffer() {
        let one = ChapMascot.swimFrame(elapsed: 3, laneCells: 200, startOffset: 0)
        let two = ChapMascot.swimFrame(elapsed: 3, laneCells: 200, startOffset: 37)
        #expect(one.x != two.x)
    }

    @Test("with Reduce Motion it floats still in the middle")
    func restsInMiddle() {
        let frame = ChapMascot.restingSwimFrame(laneCells: 200)
        #expect(frame.x == (200 - ChapMascot.width) / 2)
        #expect(frame.bob == 0 && frame.pose == .rest)
    }
}
