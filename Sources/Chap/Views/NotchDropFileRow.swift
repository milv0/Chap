import SwiftUI

/// 메인 노치 도커 아래의 Chap Drop 파일 행. 패널은 목록만 공급하고, 열기·드래그·제거 UI는 이 뷰가 맡는다.
struct NotchDropFileRow: View {
    let files: [URL]
    let headingForeground: Color
    let primaryForeground: Color
    let subtleSurface: Color
    let textShadowOpacity: Double
    let hoverBackground: Color

    var body: some View {
        if !files.isEmpty {
            VStack(alignment: .leading, spacing: DS.spacingSmall) {
                Rectangle()
                    .fill(subtleSurface)
                    .frame(height: 1)
                    .padding(.top, 2)
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(DS.notchLabel)
                        .foregroundColor(headingForeground)
                        .padding(.horizontal, 6)
                        .accessibilityHidden(true)
                    ForEach(files, id: \.self) { url in
                        NotchDropFileItem(
                            url: url,
                            primaryForeground: primaryForeground,
                            textShadowOpacity: textShadowOpacity,
                            hoverBackground: hoverBackground
                        ) {
                            ChapDrop.removeAsync(url) { removed in
                                if !removed {
                                    LauncherUtils.showAlert(
                                        message: "File could not be removed",
                                        info:
                                            "Chap could not remove \(url.lastPathComponent) from Drop."
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
