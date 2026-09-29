import Foundation

/// 노치 선반(Screenshots·Downloads) 제목을 눌러 폴더를 열 때의 창 규칙.
/// 설정에 없는 일회성 Finder 런처를 만들어 일반 Finder 실행과 같은 경로로 연다:
/// Standard 크기 프리셋, 커서가 있는 화면 가운데.
public enum ShelfFolderLaunch {
    /// 선반 폴더 창의 기본 크기 프리셋.
    public static let presetID = WindowSizePresets.standard.id

    /// 선반 폴더를 여는 일회성 Finder 런처. 디스플레이를 지정하지 않아 커서 화면을 따른다.
    public static func site(name: String, folderPath: String) -> Site {
        Site(
            name: name, url: "", width: Defaults.defaultWidth, height: Defaults.defaultHeight,
            windowSizePreset: presetID, launchType: .finder, folderPath: folderPath)
    }
}
