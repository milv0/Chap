import SwiftUI

// MARK: - Focus 칸의 Timer 모드

/// Timer 모드 본문. Focus와 같은 다이얼로 5~60분(5분 눈금)을 고르고 가운데를 눌러 시작한다.
/// 돌고 있으면 남은 시간만큼 호가 줄어들고, 가운데를 누르면 멈춘다. 메뉴의 Timer와 같은 타이머다.
/// 노치가 접혀 있는 동안 남은 시간은 노치 왼쪽 배지(`NotchTimerBadgeView`)가 보여 준다.
struct NotchFocusTimerBody: View {
    let palette: NotchWidgetPalette
    let endDate: Date?

    /// 마지막으로 고른 타이머 길이(초). 메뉴로 시작한 타이머와는 따로 기억한다.
    @AppStorage("ChapTimerLength") private var storedLength = TimerPolicy.defaultLength
    @State private var isCenterHovered = false

    private var chosenLength: TimeInterval { TimerPolicy.length(forStored: storedLength) }

    private func setLength(_ next: TimeInterval) {
        guard next != chosenLength else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        storedLength = next
    }

    private func start() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        NotificationCenter.default.post(
            name: NotchFocusView.timerStartRequest, object: chosenLength)
    }

    var body: some View {
        if let endDate, endDate > Date() {
            running(until: endDate)
        } else {
            idle
        }
    }

    /// 꺼짐: 다이얼을 끌어 길이를 맞추고(5분 눈금, 마지막 값 기억), 가운데를 누르면 시작한다.
    private var idle: some View {
        FocusDial(
            fraction: TimerPolicy.dialFraction(length: chosenLength),
            isRunning: false, palette: palette, maxLabel: TimerPolicy.dialMaxLabel,
            onPick: { setLength(TimerPolicy.dialLength(fraction: $0)) }
        ) {
            Button(action: start) {
                FocusDialInner(isHovered: isCenterHovered, hoverTint: DS.accent.opacity(0.10)) {
                    FocusDialCenterLabel(
                        value: TimerPolicy.dialLabel(length: chosenLength),
                        caption: TimerPolicy.dialStartLabel, valueSize: 20,
                        valueColor: palette.primary, captionColor: DS.accent)
                }
            }
            .buttonStyle(FocusPressStyle())
            .onHover { isCenterHovered = $0 }
            .help(
                "Start a \(TimerPolicy.presetTitle(chosenLength).lowercased()) timer. "
                    + "Drag the dial to change."
            )
            .accessibilityLabel("Start \(TimerPolicy.presetTitle(chosenLength)) timer")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timer length")
        .accessibilityValue(TimerPolicy.presetTitle(chosenLength))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setLength(TimerPolicy.stepped(chosenLength, by: 1))
            case .decrement: setLength(TimerPolicy.stepped(chosenLength, by: -1))
            @unknown default: break
            }
        }
    }

    /// 돌고 있음: 같은 0~60분 눈금에서 남은 시간까지 호가 줄어들고, 가운데에 남은 시간.
    /// 안쪽 원을 누르면 멈춘다(마우스를 올리면 "Stop"이 빨강).
    private func running(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(end.timeIntervalSince(context.date), 0)
            FocusDial(
                fraction: TimerPolicy.dialFraction(length: remaining),
                isRunning: true, palette: palette, maxLabel: TimerPolicy.dialMaxLabel, onPick: nil
            ) {
                Button {
                    NotificationCenter.default.post(
                        name: NotchFocusView.timerStopRequest, object: nil)
                } label: {
                    FocusDialInner(
                        isHovered: isCenterHovered, hoverTint: palette.primary.opacity(0.06)
                    ) {
                        FocusDialCenterLabel(
                            value: TimerPolicy.clockLabel(until: end, now: context.date),
                            caption: TimerPolicy.dialStopLabel, valueSize: 18,
                            valueColor: palette.primary,
                            captionColor: isCenterHovered ? DS.danger : palette.secondary)
                    }
                }
                .buttonStyle(FocusPressStyle())
                .onHover { isCenterHovered = $0 }
                .help("Stop the timer")
                .accessibilityLabel(
                    "Timer, \(TimerPolicy.clockLabel(until: end, now: context.date)) left"
                )
                .accessibilityHint("Stops the timer")
            }
        }
    }
}
