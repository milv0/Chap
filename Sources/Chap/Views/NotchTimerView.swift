import SwiftUI

/// 노치 한 칸의 타이머. 꺼져 있으면 길이를 −/+로 맞추고(5분 단위, 마지막 값 기억) Start,
/// 돌고 있으면 남은 시간과 줄어드는 진행선, Stop. 메뉴의 Timer와 같은 타이머다.
/// 노치가 접혀 있는 동안 남은 시간은 노치 왼쪽 배지(`NotchTimerBadgeView`)가 보여 준다.
struct NotchTimerView: View {
    let palette: NotchWidgetPalette
    /// 도커를 열 때 돌고 있던 타이머. 이후 변화는 알림으로 받는다.
    @State var endDate: Date?
    @State var length: TimeInterval?

    /// 시작·중지 요청. AppDelegate가 `ChapTimerController`로 전달한다. 시작 object는 길이(초).
    static let startRequest = Notification.Name("ChapTimerStartRequest")
    static let stopRequest = Notification.Name("ChapTimerStopRequest")

    @AppStorage("ChapTimerLength") private var storedLength = TimerPolicy.defaultLength

    private var chosenLength: TimeInterval { TimerPolicy.length(forStored: storedLength) }

    static let columnWidth: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            NotchWidgetHeader(
                symbol: "timer", title: "Timer",
                palette: endDate == nil ? palette : palette.withIcon(DS.accent))
            Group {
                if let endDate, endDate > Date() {
                    running(until: endDate)
                } else {
                    idle
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: widgetBodyHeight, alignment: .center)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ChapTimerController.didChangeNotification)
        ) { note in
            endDate = note.object as? Date
            length = (NSApp.delegate as? AppDelegate)?.chapTimer.length
        }
    }

    // MARK: - Idle

    private var idle: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                stepButton(symbol: "minus", direction: -1)
                Text(TimerPolicy.clockLabel(length: chosenLength))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(palette.primary)
                    .frame(minWidth: 52)
                    .accessibilityHidden(true)
                stepButton(symbol: "plus", direction: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Timer length")
            .accessibilityValue(TimerPolicy.presetTitle(chosenLength))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(1)
                case .decrement: step(-1)
                @unknown default: break
                }
            }
            capsule("Start", tint: .white, fill: DS.accent) {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .levelChange, performanceTime: .now)
                NotificationCenter.default.post(name: Self.startRequest, object: chosenLength)
            }
            .help("Start a \(TimerPolicy.presetTitle(chosenLength).lowercased()) timer")
            .accessibilityLabel("Start \(TimerPolicy.presetTitle(chosenLength)) timer")
        }
    }

    private func stepButton(symbol: String, direction: Int) -> some View {
        let next = TimerPolicy.stepped(chosenLength, by: direction)
        return Button {
            step(direction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(palette.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(palette.subtleSurface))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(next == chosenLength)
        .opacity(next == chosenLength ? 0.4 : 1)
        .accessibilityHidden(true)
    }

    private func step(_ direction: Int) {
        let next = TimerPolicy.stepped(chosenLength, by: direction)
        guard next != chosenLength else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        storedLength = next
    }

    // MARK: - Running

    private func running(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 8) {
                Text(TimerPolicy.clockLabel(until: end, now: context.date))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                progressBar(
                    TimerPolicy.progress(
                        end: end, length: length ?? chosenLength, now: context.date))
                capsule("Stop", tint: palette.primary, fill: palette.subtleSurface) {
                    NotificationCenter.default.post(name: Self.stopRequest, object: nil)
                }
                .help("Stop the timer")
                .accessibilityLabel("Stop timer")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                "Timer, \(TimerPolicy.clockLabel(until: end, now: context.date)) left")
        }
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.primary.opacity(0.12))
                // 남은 시간만큼 남는 막대. 지날수록 줄어든다.
                Capsule()
                    .fill(DS.accent)
                    .frame(width: geometry.size.width * (1 - progress))
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(width: 84, height: 4)
        .accessibilityHidden(true)
    }

    private func capsule(
        _ title: String, tint: Color, fill: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.notchMeta.weight(.semibold))
                .foregroundColor(tint)
                .padding(.horizontal, 14)
                .frame(height: 20)
                .background(Capsule().fill(fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 노치가 접혀 있을 때 노치 왼쪽에 붙는 타이머 배지. Drop 배지(오른쪽)를 좌우로 뒤집은 모양이다:
/// 노치 쪽(오른쪽)은 직선으로 하드웨어와 이어지고, 바깥(왼쪽)은 오목 플레어로 메뉴 막대에 합류한다.
struct NotchTimerBadgeView: View {
    let endDate: Date

    var body: some View {
        ZStack {
            NotchBadgeShape(
                flareRadius: NotchGeometry.dockFlareRadius,
                bottomCornerRadius: NotchGeometry.badgeCornerRadius
            )
            .fill(Color.black)
            .scaleEffect(x: -1, y: 1)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = endDate.timeIntervalSince(context.date)
                Text(TimerPolicy.clockLabel(until: endDate, now: context.date))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    // 마지막 1분은 액센트로 바꿔 곧 끝난다는 것만 조용히 알린다.
                    .foregroundColor(remaining <= 60 ? DS.accentLight : DS.notchStripIconColor())
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(
                        "Timer, \(TimerPolicy.clockLabel(until: endDate, now: context.date)) left")
            }
            .padding(.leading, NotchGeometry.dockFlareRadius)
            .padding(.trailing, NotchLauncherPolicy.dropBadgeNotchOverlap)
        }
    }
}
