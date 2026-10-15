import SwiftUI

/// 노치가 접혀 있을 때 노치 왼쪽에 붙는 타이머 배지. Drop 배지(오른쪽)를 좌우로 뒤집은 모양이다:
/// 노치 쪽(오른쪽)은 직선으로 하드웨어와 이어지고, 바깥(왼쪽)은 오목 플레어로 메뉴 막대에 합류한다.
struct NotchTimerBadgeView: View {
    let endDate: Date

    var body: some View {
        ZStack {
            NotchBadgeShape(
                flareRadius: NotchGeometry.badgeFlareRadius,
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
            .padding(.leading, NotchGeometry.badgeFlareRadius)
            .padding(.trailing, NotchLauncherPolicy.dropBadgeNotchOverlap)
        }
    }
}
