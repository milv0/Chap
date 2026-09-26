# Notch Surface Geometry Spec

노치 표면(메인 패널·Chap Drop 도커·Drop 배지)의 시각 스펙.
**모든 수치의 단일 출처는 `Sources/ChapCore/NotchGeometry.swift`** 이며,
이 문서는 각 수치가 화면 어디에 해당하는지 보여주는 지도다.

스펙을 조정하고 싶을 때: 아래 이름으로 값을 지정하거나("badgeNotchOverlap을
8로"), 스크린샷에 마킹해서 전달하면 된다.

## 배치 다이어그램

```
 화면 최상단 ────────────────────────────────────────────────────────
 │  menu bar     [═══════ notch (hardware) ═══════]▓▓[■ 34×32]╮    │
 │                        185 × 32 (runtime)     (12+34+10)×32 │    │
 └────────────────────────────────────────────────────────────┴────┘
                     badgeNotchOverlap 12 (노치 밑으로 파고듦 ▓) ↑
                     보이는 본체 badgeBodyWidth 34 × 32, 플레어 10은 그 바깥  ↑
                     하단 바깥: badgeCornerRadius 6 볼록          ↑

 도커가 펼쳐지면 (노치 중앙 정렬):
              ╭──flare 10                        flare 10──╮
              │ [left span 32][═ notch 185 ═][badge span 32]│
              │                                             │
              ╰──dockBottomRadius 18 (모든 도커 공통)     ───╯
```

## 좌우 배지

- **오른쪽 Drop 배지**: 보관함에 파일이 있을 때 표시. hover하면 메인
  도커가 열리고, 직접 드롭도 받는다. 파일을 끌고 노치·배지에 대면 메인
  도커 위에 반투명 "Drop here" 레이어가 덮인다. Drop 파일들은 메인 도커
  하단의 가로 아이콘 행(파일이 있을 때만 표시)으로 보여준다.
- **왼쪽 상태 영역**: 별도 배지 창은 두지 않는다. Keep Awake 시작/종료는
  상단바 아이콘 색과 중앙 HUD가 담당하고, 메인 도커가 열렸을 때만 왼쪽
  plateau 안에 파란 커피 아이콘 + h:mm:ss 남은 시간을 1초마다 렌더링한다.
  묶음은 영역 중심에서 오른쪽으로 `awakeStatusOffsetX`만큼 보정한다.

## 실루엣 문법: 오목 플레어

모든 노치 표면(메인 패널·Drop 도커·드롭 존·배지)의 **상단 모서리는 볼록
라운드가 아니라 오목 플레어**다. `NotchDockShape`의 상단은 상단바 라인에서
바깥으로 흐르는 오목 곡선(반경 `dockFlareRadius`)으로 시작해 본체 벽으로
이어진다 — 실제 노치가 메뉴바와 만나는 방식과 같은 문법이라 표면이
"상단바에서 빠져나온" 것처럼 보인다.

이 구조의 부작용 두 가지를 항상 기억할 것:

1. **벽 인셋** — 본체 벽은 프레임보다 좌우 각 `dockFlareRadius`만큼
   안쪽에 선다. 메인 패널은 `NotchDockShape`과 동일한 geometry를 공유하고,
   Drop 배지는 별도 `NotchBadgeShape`으로 노치 쪽 직선 변과 바깥 플레어를 만든다.
2. **림 스트로크** — 림 하이라이트는 상단 변을 긋지 않는 `isRim` 경로를
   써야 노치 경계에 흰 줄이 생기지 않는다.

배지도 같은 `NotchDockShape`을 쓴다: 상단 오목 플레어 + 하단 볼록
(`badgeCornerRadius`). 노치 쪽 절반은 겹침(overlap)으로 하드웨어 밑에
숨고 바깥 프로필만 보인다.

## 수치 표

| 이름 | 값 | 의미 |
|---|---|---|
| `stripPlateauSideWidth` | 110 | 노치 좌우의 평평한 검정 상태 영역 폭 |
| `awakeStatusOffsetX` | -2 | 왼쪽 상태 영역 안의 h:mm:ss 커피+시간 묶음 좌측 광학 보정 |
| `badgeBodyWidth` | 34 | 배지 본체(보이는 검정) 폭. 높이는 노치 높이 |
| `badgeNotchOverlap` | 12 | 배지가 노치 밑으로 파고드는 겹침 (우측 배지 → 노치의 둥근 오른쪽 아래 모서리를 채움) |
| `badgeCornerRadius` | 6 | 배지 하단 볼록 모서리 (하드웨어 노치 곡률에 근접). 상단은 `dockFlareRadius` 오목 플레어 |
| `dockFlareRadius` | 10 | 도커 상단 오목 플레어. 상단바에서 흘러나오는 곡선. **폭 보정 계산과 공유** |
| `dockBottomRadius` | 18 | 메인 도커 하단 라운드. 배지만 비례상 작은 `badgeCornerRadius` |
| `glassEdgeBleed` | 10 | Glass 광학 edge를 플레어 밖으로 밀어 검정 꼭짓점까지 재질 연결 |
| `contentTopGap` | 15 | 노치 하단 경계와 섹션 콘텐츠 사이 세로 간격 |
| `stripEdgeDepth` | 6 | 눌린 검정 띠가 도커 끝에서 남는 최소 깊이 |
| `stripFalloff` | 90 | plateau 밖에서 곡선으로 얇아지는 감쇠 길이. 최대 깊이는 노치 세로와 동일 |
| `shadowPadding` | 28 | 그림자 클리핑 방지 투명 여백 |

## 런타임 파생 값 (하드코딩 아님)

기종·디스플레이 스케일에 따라 달라지므로 화면 API에서 매번 계산한다.

| 값 | 계산 | 14" MBP 기본 스케일 기준 |
|---|---|---|
| 노치 높이 | `safeAreaInsets.top` | 32pt |
| 노치 폭 | `auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX` (nil이면 200 폴백) | 185pt |
| 배지 한 변 | 노치 높이 | 32pt |
| Drop 도커 검정 폭 | 노치 폭 + badgeBodyWidth × 2 + 플레어 × 2 | 273pt |

## 스타일

Style 피커는 **Custom / Glass** 두 가지만 제공한다. Custom은 색상·불투명도
설정을, Glass는 System/Light/Dark appearance를 노출한다.

| 스타일 | 콘텐츠 박스 | 비고 |
|---|---|---|
| Custom | 사용자 색 + 불투명도 페이드 | 기본. 과거 Black/Iceberg 설정은 이 스타일로 마이그레이션 |
| Glass | Liquid Glass 재질 (macOS 26+) | 상단 띠는 검정 유지, 26 미만은 Custom 기본 검정과 동일 |

상단바 띠는 어떤 스타일에서도 순검정이다 — 노치와 융합해야 하므로
유리·색이 침범하지 않는다.

Apple 공식 API는 연속 강도를 제공하지 않고 `Glass.clear`와
`Glass.regular` 두 재질 변형을 제공한다. appearance와의 조합은 정책으로 고정한다:

- `system`: `NSPanel.appearance = nil` — macOS Light/Dark 변경을 자동 추적하며,
  사용자가 Clear/Regular를 직접 고른다
- `light`: `NSAppearance(named: .aqua)` + **Clear** 고정 — 더 옅은 라이트 유리
- `dark`: `NSAppearance(named: .darkAqua)` + **Regular** 고정 — 대비가 강한 다크 유리

렌더러도 `resolvedMaterial` 정책을 적용해 config를 수동 편집해도 이 페어가 유지된다.

노치 UI는 Settings와 별도 `NSPanel`이므로 SwiftUI `colorScheme`만 바꾸지 않고
패널 자체에 appearance를 적용한다. Settings에서 재질 또는 appearance를 바꾸면
메인 도커를 2.5초 동안 자동으로 펼쳐 새 디자인을 프리뷰한다. 재질 변경은 이미 열린
SwiftUI 뷰를 새 재질로 재구성한다. Glass 콘텐츠 텍스트는 semantic
`primary`/`secondary`, 기능 아이콘은 Chap accent, hover 면은 appearance에
적응하는 `primary.opacity(0.08)`을 쓴다.

Glass는 custom 오목 플레어 경계에서 시스템 광학 edge가 안쪽으로 물러나
배경화면 틈이 생기지 않도록 두 장치를 쓴다:

1. `glassEdgeBleed`: Glass 효과의 광학 edge를 외곽으로 밀고 본체 셰이프로 마스킹
2. `GlassCornerBridgeShape`: 좌우 오목 코너의 빈 wedge를 Glass로 채워 재질이
   화면 상단 플레어 꼭짓점까지 직접 닿게 함
3. Glass의 `PressedStripShape.edgeDepth`는 0: 검정 띠가 외곽 코너에서 완전히
   사라지므로, 상단 좌우 둥근 꼭짓점에 보이는 재질은 검정이 아니라 Glass다

검정 `PressedStripShape`은 bridge 위에 별도로 그리되 본체 셰이프로 클립해
중앙 노치·배지 plateau는 검정으로 유지한다. Custom은 기존 `stripEdgeDepth` 6을
유지해 검정 상단 띠가 외곽에도 남는다.

## 가독성 기준 (Apple HIG)

콘텐츠 박스 색을 사용자가 자유롭게 고르므로 전경색은 배경 휘도에 따라
자동 적응한다. 기준은 Apple HIG의 대비 규칙(텍스트 4.5:1 최소·7:1 권장,
비텍스트 3:1)이며 규칙은 `NotchContrastPolicy`가 테스트로 고정한다.

| 요소 | 어두운 Custom 배경 | 밝은 Custom 배경 | Glass |
|---|---|---|---|
| 섹션 아이콘 | 테마 블루 또는 흰색 | 테마 블루 또는 검정 (3:1 기준) | 테마 블루 |
| 섹션 라벨 | 흰색 계층 | 검정 65% | semantic secondary |
| 단축키 힌트 | 흰색 계층 | 검정 50% | semantic secondary |
| 본문 텍스트 | 흰 96% + 그림자 | 검정 87%, 그림자 없음 | semantic primary |

참고: https://developer.apple.com/design/human-interface-guidelines/color

## 모션 기준

모든 노치 표면이 같은 타이밍 기준을 쓴다. 닫힘 관련 값은 전부
`closeDuration` 하나에서 파생된다.

| 이름 | 값 | 의미 |
|---|---|---|
| `openAnimation` | spring 440/30 (~0.3s) | 패널 펼침. 노치 상단 기준 스프링 확장 |
| `closeDuration` | 0.18s | 메인 패널 접힘 시간 |
| 창 제거 | closeDuration + 0.02s | 닫힘 애니메이션 종료 직후 |
| `hideDelay` | 0.2s | 마우스가 영역 밖에 머물면 닫힘 판정 |
| `hoverMargin` | 0 | 노치·배지의 hover/드래그 인식 범위는 시각 경계와 동일 |
| `pollInterval` | 0.08s | 마우스 위치 폴링 주기 |


## 설정 Import/Export

Export는 hidden menu와 노치 설정을 포함한 현재 Config 전체를 보존한다.
Import는 launchable·일반·hidden menu 설정을 적용하지만, 노치 설정은 기기
하드웨어에 종속되므로 현재 기기의 값을 유지한다.

## 관련 파일

- `Sources/ChapCore/NotchGeometry.swift` — 수치의 단일 출처
- `Sources/ChapCore/NotchLauncherPolicy.swift` — 표시 조건·프레임 계산 (테스트로 고정)
- `Sources/Chap/Views/NotchLauncherPanelView.swift` — 메인 패널 + 도커 실루엣 셰이프
- `Sources/Chap/Views/NotchDropViews.swift` — Drop 도커·드롭 존·배지
- `Sources/Chap/NotchLauncherController.swift` — 창 배치·표시 로직
