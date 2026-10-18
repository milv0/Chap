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
                     badgeNotchOverlap 18 (노치 밑으로 파고듦 ▓) ↑
                     보이는 본체 badgeBodyWidth 34 × 32, 플레어 badgeFlareRadius 6은 그 바깥  ↑
                     하단 바깥: badgeCornerRadius 13 볼록(연속 곡률, 하드웨어 노치와 같은 곡률)          ↑

 도커가 펼쳐지면 (노치 중앙 정렬):
              ╭──flare 10                        flare 10──╮
              │ [left span 32][═ notch 185 ═][badge span 32]│
              │                                             │
              ╰──dockBottomRadius 18 (모든 도커 공통)     ───╯
```

## 노치가 없는 화면

노치가 없어도 같은 도커를 쓴다. 가짜 노치를 그리지 않는 것이 규칙이다.

- 화면: `NotchLauncherController.dockScreen()` — 노치 화면이 있으면 그 화면, 없으면 메뉴 막대가 있는 주 화면.
- 검정 띠 높이: `NotchLauncherPolicy.stripInset`이 노치 높이 대신 **메뉴 막대 높이**(최소 24pt)를 쓴다.
  띠가 메뉴 막대를 정확히 덮어 도커가 화면 위에서 자라난 것처럼 보인다.
- 노치 폭: `syntheticNotchWidth` 200pt (하드웨어 폭을 못 읽을 때의 폴백과 같은 값).
- 여는 법: 상단에 **창을 띄우지 않는다**. `hoverZone`(화면 위쪽 가운데 200pt × 띠 높이)에 마우스가
  들어오는 순간만 150ms 폴링으로 감지해 도커를 연다. 닫은 뒤에는 한 번 벗어나야 다시 열린다.
- Drop 배지: 두지 않는다. 늘 떠 있는 검정 배지가 메뉴 막대를 가리고 그 자리의 클릭을 삼킨다.
  파일을 끌어 위쪽 가운데로 가면 도커가 열리고, 도커의 Drop 레이어가 받는다.
- 이유: 메뉴 막대 위의 투명 창은 그 자리의 클릭을 삼켜 앱 메뉴를 못 열게 만든다. 노치 Mac에서는
  하드웨어 노치가 그 자리라 문제가 없었다.

## 좌우 배지

- **오른쪽 Drop 배지**: 보관함에 파일이 있을 때 표시. hover하면 메인
  도커가 열리고, 직접 드롭도 받는다. 파일을 끌고 노치·배지에 대면 메인
  도커 위에 반투명 "Drop here" 레이어가 덮인다. Drop 파일들은 메인 도커
  하단의 가로 아이콘 행(파일이 있을 때만 표시)으로 보여준다.
- **왼쪽 상태 영역**: 별도 배지 창은 두지 않는다. Keep Awake 시작/종료는
  상단바 아이콘 색과 중앙 HUD가 담당한다. 남은 시간은 Keep Awake 칸 다이얼이 보여 주고,
  띠 왼쪽에는 물범(과 접힌 선반 아이콘)이 있다.

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
   배지(Drop·Timer)만은 하드웨어 노치 옆에 나란히 보이므로 도커 값이 아니라 노치 곡률을 따른다:
   플레어 `badgeFlareRadius` 6, 아래 모서리 `badgeCornerRadius` 13 `.continuous`.
   애플이 노치 곡률을 공개하지 않아 실측에 가까운 근사치다.
2. **림 스트로크** — 림 하이라이트는 상단 변을 긋지 않는 `isRim` 경로를
   써야 노치 경계에 흰 줄이 생기지 않는다.

배지도 같은 `NotchDockShape`을 쓴다: 상단 오목 플레어 + 하단 볼록
(`badgeCornerRadius`). 노치 쪽 절반은 겹침(overlap)으로 하드웨어 밑에
숨고 바깥 프로필만 보인다.

## 수치 표

| 이름 | 값 | 의미 |
|---|---|---|
| `stripPlateauSideWidth` | 110 | 노치 좌우의 평평한 검정 상태 영역 폭 |
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
설정을, Glass는 System/Light/Dark appearance와 Clear/Regular 재질을 각각 노출한다.

| 스타일 | 콘텐츠 박스 | 비고 |
|---|---|---|
| Custom | 사용자 색 + 불투명도 페이드 | 기본. 과거 Black/Iceberg 설정은 이 스타일로 마이그레이션 |
| Glass | Liquid Glass 재질 (macOS 26+) | 상단 띠는 검정 유지, 26 미만은 Custom 기본 검정과 동일 |

상단바 띠는 어떤 스타일에서도 순검정이다 — 노치와 융합해야 하므로
유리·색이 침범하지 않는다.

Apple 공식 API는 연속 강도를 제공하지 않고 `Glass.clear`와
`Glass.regular` 두 재질 변형을 제공한다. appearance와 재질은 서로 독립적으로 고른다:

- appearance는 패널의 `NSAppearance`만 정한다 — `system`은 `NSPanel.appearance = nil`
  (macOS Light/Dark 자동 추적), `light`은 `NSAppearance(named: .aqua)`,
  `dark`는 `NSAppearance(named: .darkAqua)`
- 재질은 appearance와 무관하게 `config.notchGlassMaterial` 값을 그대로 쓴다.
  어떤 appearance에서도 Clear·Regular를 자유롭게 조합할 수 있다

`resolvedMaterial` 정책은 더 이상 없다. 렌더러(`glassMaterialProvider`)는
`config.notchGlassMaterial`을 직접 전달하고, Settings의 Glass Material 피커는
Glass 스타일일 때 항상 노출된다.

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
3. `PressedStripShape.edgeDepth`는 0: 검정 띠가 외곽 코너에서 완전히
   사라지므로, 상단 좌우 둥근 꼭짓점에 보이는 재질은 검정이 아니라 패널 재질이다

검정 `PressedStripShape`은 bridge 위에 별도로 그리되 본체 셰이프로 클립해
중앙 노치·배지 plateau는 검정으로 유지한다. **Custom(Mist 등)과 Glass 폴백도 같다**: bridge를 본체와 같은
`panelFill`로 채우고 `edgeDepth` 0을 써서, 모든 테마에서 상단 좌우 꼭짓점에 닿는 것은 검정이 아니라 패널 색이다.
(`stripEdgeDepth` 6은 `PressedStripShape`의 기본값으로만 남아 있다.)

## 가독성 기준 (Apple HIG)

콘텐츠 박스 색을 사용자가 자유롭게 고르므로 전경색은 배경 휘도에 따라
자동 적응한다. 기준은 Apple HIG의 대비 규칙(텍스트 4.5:1 최소·7:1 권장,
비텍스트 3:1)이며 규칙은 `NotchContrastPolicy`가 테스트로 고정한다.

| 요소 | 어두운 Custom 배경 | 밝은 Custom 배경 | Glass |
|---|---|---|---|
| 섹션 라벨 | 흰색 보조 계층 | 검정 65% | semantic secondary |
| 섹션 아이콘 | 밝은 블루 #89A3FF 90% | 액센트 75% | 라이트 액센트 75%, 다크 밝은 블루 90% |
| 상단 띠 위젯 아이콘 | 흰색 85% (호버 100%), 켜진 도구는 액센트 | 같음 | 같음 |
| 키캡 글자 / 바탕 | 본문색 80% / 14% | 본문색 80% / 14% | primary 80% / 14% |
| 본문 텍스트 | 흰 96% + 그림자 | 검정 87%, 그림자 없음 | semantic primary |

글자 크기: 목록 줄 이름 12pt(`DS.notchRowName`), 메모 본문 13pt(`DS.notchBody`), 제목·키캡 11pt semibold(`DS.notchLabel`),
보조 정보 10pt medium(`DS.notchMeta`, 노치 최소 크기).
**목록 줄 통일**: Sites·Finder·Downloads 줄은 모두 12pt 이름(`DS.notchRowName`) + 오른쪽 보조 정보(키캡·받은 시각),
높이 26pt다. **줄 앞 아이콘은 줄마다 다른 정보를 줄 때만** 둔다: Downloads는 파일 아이콘·썸네일(16pt,
`DS.notchRowIconSize`), Apps는 앱 아이콘 격자. Sites·Finder는 모든 줄이 같은 기호가 되고 칸 제목 아이콘과 겹치므로
아이콘 없이 이름만 둔다. 긴 이름은 가운데를 줄인다. 칸 폭은 `NotchTextMetrics.rowWidth`가 키캡("⌥키" 폭)까지 재서 잡는다.
**스크린샷 없음 → 저절로 접힘**: 스크린샷이 하나도 없으면 Screenshots 칸은 검정 띠 왼쪽 아이콘으로 저절로 접힌다
(`ShelfAutoCollapsePolicy.collapsesScreenshots`, 저장하지 않음). 열려 있는 동안 2초마다 확인해 스크린샷이 생기면
펼쳐진다. 아이콘을 누르면 이번에 열린 동안만 펼쳐 둔다. 마지막 확인값(`ScreenshotShelf.lastKnownEmpty`)으로 시작해
열자마자 도커가 줄어드는 움직임이 없다.
**빈 선반**: 다 읽은 뒤 비어 있으면 "No screenshots yet" / "No downloads yet"를 10pt 한 줄로 쓰고, 칸은 제목 + 폴더
화살표 + 접기 버튼 폭으로 좁아진다(`emptyShelfWidth`). 파일이 생기면 원래 폭으로 돌아간다. 모든 칸의 제목 줄은 16pt(`notchHeaderHeight`),
목록·스크린샷 행은 26pt로 같아 가로로 줄이 맞는다. 스크린샷 행은 잘리는 파일명 대신 34×22pt 썸네일(왼쪽)과
"5 min ago" 같은 상대 시각(오른쪽 끝 정렬, 10pt 보조색·고정폭 숫자, 다운로드 칸과 같은 크기)을 보여주고, 파일명은 툴팁·VoiceOver로 제공한다.
Glass Clear에는 창 배경색 28% 베일을 얹어 뒤 화면이 복잡해도 대비를 확보한다. 새 설정의 기본 재질은 Regular다.

참고: https://developer.apple.com/design/human-interface-guidelines/color

## 위젯 칸

위젯은 6칸 한 줄이다. 빈 칸은 그리지 않고, 칸마다 내용에 맞는 폭을 쓴다.
도커 최소 폭은 640pt(또는 노치 + 양쪽 상태 영역 110pt씩 + 80pt 중 큰 값, `NotchLauncherPolicy.dockMinWidth`)이고,
위젯 줄이 그보다 좁으면 가운데 정렬한다. Drop 파일 줄은 왼쪽 정렬을 유지한다.

| 칸 | 폭 |
|---|---|
| Screenshots | 썸네일 34 + 가장 긴 시각 문구 기준, 112–170pt |
| Downloads | 200pt (12pt 파일명, 20자 안팎) |
| Keep Awake | 104pt 다이얼과 제목 줄("⚡ Keep Awake" + 타이머 탭 25pt) 중 넓은 쪽, 최소 116pt(지금 약 127pt, `focusColumnWidth`). Keep Awake·Timer 모드 공용 |
| To-do | 140–240pt (가장 긴 항목·추가 줄·제목 줄 중 넓은 쪽, `TodoColumnPolicy`). 도커를 열 때 정하고 열려 있는 동안은 고정 |
| Launchers | 112–170pt (Sites·Finder 중 가장 넓은 목록, 제목 + 탭 아이콘은 늘 들어감) |
| Apps | 112–170pt (Apps 격자(2열 80pt·3열 122pt)와 Layouts 2열 타일 108pt 중 넓은 쪽, 제목 + 탭 아이콘은 늘 들어감) |

글자 폭은 `NotchTextMetrics`가 실제 글꼴(13pt 본문, 11pt semibold)로 재고 SwiftUI 렌더링 여유를 더한다. 놓을 수 있는 위젯
(Screenshots·Downloads·Launchers·Apps·Keep Awake·To-do) 여섯이 모두 한 번에 들어가는 수라서 페이지를 두지 않는다. 2.1의 12칸 설정은 뒤쪽 위젯을 앞쪽 빈 칸으로
당겨 6칸에 옮기고, 2.0의 4칸 설정은 순서 그대로 앞 4칸이 된다.
2.16에서 없앤 위젯은 자리를 지킨 채 바뀐다(`NotchWidget.migratedSlots`): 첫 Sites·Finder 칸은 Launchers, 그다음은 빈 칸.
Workspaces 칸(지금 이름 Layouts)은 Apps(이미 Apps가 있으면 빈 칸). 칸을 지워 당기지 않아 나머지 배치가 그대로다.

**선반 칸 고정**: 앞 두 칸은 선반 자리로 주인이 정해져 있다. 1번 칸 Screenshots, 2번 칸 Downloads
(`NotchWidget.shelfSlots`, `fits(slot:)`). 다른 위젯은 3~6번 칸에만 놓인다. 선반은 접으면 검정 띠 **왼쪽** 아이콘이
되므로 펼쳐지는 자리도 늘 맨 왼쪽이어야 아이콘과 칸이 같은 쪽에 있다. 설정 화면은 Slots("Default" 묶음의 Screenshots·Downloads 두 칸 · "Widgets" 네 칸을 떨어뜨린 보드, 아래에 아직 안 놓은 위젯만 한 줄),
Notch Icons(Mirror·Quick Note·Cover Screens 아이콘 표시 스위치), Appearance 세 묶음이다. 기능의 단축키·동작은 Tools 탭에 있다. 선반 칸(`ShelfSlotToggle`)은 체크 표시가
달린 켜기/끄기 버튼이라 끌어 옮기거나 서로 바꾸거나 다른 위젯을 놓을 수 없고, 팔레트에도 선반이 없다. 이전 배치는 읽을
때 선반을 고정 칸으로 옮기고 나머지 순서(빈 칸 포함)는 그대로 둔다(`normalizedSlots`). 기본 배치는 Screenshots · 빈
Downloads 칸 · Launchers · Apps · 빈 칸 · 빈 칸.

## Apps 칸: 아이콘 격자 + Layouts 탭

Apps 칸(`NotchWidget.apps`, `NotchAppsSlot`)은 Apps(앱 아이콘)와 Layouts(창 배치 타일) 두 탭이다. 둘 다 아이콘 타일이라
탭을 바꿔도 칸 모양이 같다. 제목 줄은 Launchers와 같은 `NotchTabHeader`(`■ Apps  ▤`)다. Layouts는 Capture 타일이 늘 있어
항상 탭이고, Apps 탭은 앱이 있을 때만 있다(`AppsSlotTab.available`). 마지막 탭은 UserDefaults `ChapAppsTab`에 기억한다.
고른 탭 이름 뒤 ›를 누르면 Apps는 설정의 Apps 섹션, Layouts는 Layouts 섹션을 연다(이름은 누를 수 없다).

Apps 탭은 앱 아이콘 격자다(`LauncherListPolicy.appIconColumns(forCount:)`). 4개까지는 2열(4개면 2 × 2)로 덩어리지게, 5~6개는 3열 × 2줄로 둔다. 어느 쪽이든 최대 2줄이고, 필요한 줄만 써서 위에서부터 채우며 칸 가운데에 놓는다. 아이콘 32pt, 타일 34pt 정사각(고정 폭 열), 가로 간격 8pt, 세로 간격 12pt(키캡 배지가 아래 줄과 붙지 않게). 3열 격자 폭 122pt는 Layouts 2열 타일(108pt)보다 조금 넓다. 2열 격자(80pt)는 칸 가운데에 모여 양옆이 조금 빈다. 본문은 목록 칸 4줄 높이(113pt)에 고정한다.
단축키가 있으면 아이콘 오른쪽 아래에 키 글자만(`S`) 10pt semibold 키캡으로 붙인다. 호버 시 앱 이름
툴팁과 `rowHoverBackground`, VoiceOver는 "Launch Slack, Option S". 아이콘은 `AppIconLoader`가
utility queue에서 `NSWorkspace.icon(forFile:)`로 읽고 경로별로 캐시한다.

## 상단 띠 오른쪽: Drop · Mirror · Quick Note · Cover Screens

Drop 상자(또는 배지) 오른쪽으로 `stripToolPitch`(28pt) 간격, 순서는 Mirror → Quick Note → Cover Screens
(`stripToolCenterOffsets`, 노치 오른쪽 끝에서 41·69·97pt). 셋 다 켜도 마지막 아이콘이 평평한 띠(110pt) 안에 들어온다.

- **Cover Screens**(`NotchCoverScreensStripButton`, `moon.fill`): 누르면 도커를 접고 가림막을 친다(메뉴바 항목과 같은 경로).
  가림막이 노치까지 덮으므로 끄는 것은 이 아이콘이 아니라 ⌥ 한 번(또는 아무 키 10연타)이다. 이미 켜져 있으면 무시한다.
  Notch Icons의 스위치(`notchCoverScreensEnabled`, 기본 켬)는 띠 아이콘만 숨긴다. ⌥ 키(`coverScreensShortcut`, 기본 L)와
  가림막 문구는 Settings → Tools에 있고, 아이콘을 꺼도 ⌥L과 메뉴바 항목은 그대로 쓴다.

## 상단 띠 왼쪽: 접힌 선반 · 마스코트

노치 왼쪽 검정 띠(`stripPlateauSideWidth` 110pt)에는 접힌 선반 아이콘과 Chap(아기 물범 마스코트, 이름이 곧 Chap이다,
`ChapMascot` 24×12 픽셀 × 1.5pt = 36×18pt)가 놓인다. Keep Awake 남은 시간은 더 이상 띠에 그리지 않는다
(Keep Awake 칸 다이얼과 상태 메뉴에서 본다).

물범 자리는 Keep Awake 칸이 보이든 아니든 **늘 띠 왼쪽이다**(`NotchLauncherPolicy.stripLeading()`). Keep Awake 칸은 번개와
남은 시간을 맡고, 물범은 띠에서 Keep Awake 상태를 보여 준다.

| Keep Awake 세션 | 띠 물범 |
|---|---|
| 꺼짐 | 엎드려 쉼. 눈 뜸, 가끔 까딱(7~12초), 깜빡임 |
| 켜는 순간 | 첨벙 다이빙 한 번(아래 "Keep Awake 다이빙") 뒤 원래 자리로 |
| 30분 이상 남음 | 꼬리를 0.4초 프레임으로 계속 흔듦 |
| 30분 미만 | 졸린 눈꺼풀(`Eyes.drowsy`), 꼬리를 0.7초 프레임으로 느리게 흔듦 |

- **접힌 선반 아이콘**: 흰 14pt medium(`DS.notchStripIconFont`, 띠 아이콘 공용, `DS.notchStripIconColor`, 호버 100%), 오른쪽 띠 도구와 노치를 기준으로
  대칭인 자리(노치 왼쪽 끝에서 13pt, 41pt, `leftStripIconCenterOffsets`). 왼쪽에서 오른쪽으로 칸 순서가
  읽히도록 마지막 칸이 노치에 가장 가깝다.
- **물범 자리**: 아이콘이 없으면 왼쪽 상태 영역 가운데(노치에서 55pt), 있으면 바깥쪽으로 비켜 86pt
  (`stripMascotCenterOffset`). 아이콘 두 개(노치에서 55pt까지)와 물범(68~104pt)이 겹치지 않는다.

마스코트는 `Canvas`로 픽셀마다 사각형을 칠하며, 누를 수 없고 VoiceOver에서 제외된다.
꼬리 까딱: 도커가 펼쳐지고 0.35초 뒤 한 번(`flickSequence` 들기·내리기 ×2, 프레임 0.14초),
이후 열려 있는 동안 7~12초 무작위 간격으로 반복한다. 꼬리 프레임(`tailUpRows`)은 오른쪽 끝 다섯 칸만 다르다.
`.task(id:)`가 `reveal.revealed`에 묶여 닫히면 취소되고, 동작 줄이기(Reduce Motion)가 켜져 있으면 움직이지 않는다.
깨어 있는 동안 4~7초마다 0.15초 깜빡인다(`Eyes.closed`).

**Keep Awake 다이빙(몰입)**: Keep Awake가 켜지는 순간(꺼짐 → 켜짐, 노치가 열려 있을 때) 띠 물범이 첨벙 다이빙을 한 번 한다
(`ChapMascot.focusDiveSequence`, 10프레임 × 0.1초 = 1초): 웅크림(아래 1px) → 꼬리를 들고 뛰어오름(위 3px) → 물이 차오르며
첨벙 뛰어들어 잠깐 잠김(아래 3·5px) → 꼬리를 들고 튀어 올라 첨벙 → 물이 빠지고 원래 자리. 물범은 열마다 수면(`surfaceRow`)보다
아래 부분을 그리지 않아 물속으로 들어간 모습이 된다. 물은 다이빙하는 동안만 있고, 그 뒤에는 물 없이 원래 자리에서 꼬리를 흔든다.
(물에 떠서 헤엄치기와 끝까지 잠수하기도 해 봤지만 유치하거나 상태가 안 보여 뺐다.) 이미 켜진 채 노치를 열거나 동작 줄이기·
닫힌 노치에서는 다이빙하지 않는다. 물은 물범 위에 그리는 겹침 레이어라 수면은 제자리이고 물범만 뛰고 가라앉는다.
물속 `#2440AA`, 마루 `#6E91FF`, 물방울 `#A0B9FF`.
띠에서는 z가 화면 위 경계에 잘리므로 잠든(`.asleep`) 모습 대신 쉬는 자세를 쓴다. `.asleep`·z·`widgetPixelSize`(2pt)는
`ChapMascot`에 남아 있다(2.5.0의 Keep Awake 칸 물범). 꼬리 흔들기 속도는 `focusWagFrameDuration(for:)`.
배경 위 투명 도커로 근사한다. 변수 없이 테스트하면 건너뛴다.

## Keep Awake 칸 (Keep Awake · Timer)

다이얼 하나로 두 가지를 켠다. **Keep Awake 모드**(번개)는 상태바 메뉴 Keep Awake와 같은 세션, **Timer 모드**(타이머)는
메뉴 Timer ▸와 같은 타이머다. 2.14의 Timer 칸(`"timer"`)은 디코딩할 때 Keep Awake 칸으로 바뀐다(`NotchWidget.formerTimerRawValue`,
Keep Awake 칸이 이미 있으면 빈 칸이라 다른 칸 자리는 그대로).

- **모드 전환**: 제목 줄이 탭이다. 고른 모드는 아이콘 + 제목("Keep Awake"/"Timer"), 다른 모드는 아이콘만(연하게). 누르면
  햅틱(`.alignment`)과 함께 바뀌고 UserDefaults `ChapFocusDialMode`에 기억한다. 칸을 열 때 하나만 돌고 있으면 그 모드,
  아니면 마지막 모드(`FocusDialMode.initial`). 보이지 않는 모드가 돌고 있으면 그 아이콘이 블루이고 오른쪽 위에 4pt 점.

### Keep Awake 모드
- 물범은 칸이 아니라 검정 띠에 있다(위 "상단 띠 왼쪽").
- 켜고 끄는 모습이 같은 **다이얼**이다(`FocusDial`, 104×92pt, 제목 아래 14pt 띄움 `topGap`: 호 위와 눈금 글자 아래(도커 바닥까지) 여백이 같아 보이게, 칸 가운데 정렬, 칸 폭은 제목 줄에 맞춤). 반원보다 긴 240° 호가 위를 감싸고
  아래 120°는 평평하게 열려 있다(`focusDialSweep`). 눈금은 0~12시간 하나(`focusDialFraction`), 3·6·9시간에 점, 양 끝
  아래에 "0"과 "12h".
- 꺼짐: 호(테두리 띠)를 끌면 1시간 단위(1~12시간, `focusDialHours(dx:dy:)`, 아래 빈 곳은 가까운 끝)로 맞추고, 한 칸
  넘어갈 때마다 트랙패드가 똑(`.alignment`) 한다. 고른 시간까지 블루 호 + 흰 손잡이, 가운데에는 20pt 고른 시간("4h")과 그 아래 블루 10pt "On"
  (`focusDialOnLabel`, "Chap" 없이). 따로 버튼 모양은 없고 **호 안쪽 원 전체(`FocusDialInner`, 지름 70pt)가 스위치**다(마우스를 올리면 옅게 물듦). 누르면 `FocusPressStyle`로 눌렸다 튀어 오르며 햅틱(`.levelChange`)과 함께 켠다. 마지막 시간은
  `ChapFocusPresetDuration`에 기억(기본 1시간). VoiceOver는 조절 동작(올리기·내리기)으로 바꾼다.
- 켜짐: 같은 눈금에서 남은 시간까지 블루 호가 1초마다 줄어든다(주방 타이머처럼, 끌 수 없음). 가운데에는 15pt 남은
  시간(h:mm:ss)과 그 아래 10pt "Off"(`focusDialOffLabel`, 마우스를 올리면 빨강). 안쪽 원을 누르면 끈다.
- 다이얼 길이는 `KeepAwakePolicy.focusPreset(hours:)` 세션이 되고, 앱은 메뉴 프리셋이나 1~12시간 정수만 받는다
  (`focusPreset(forRequestedDuration:)`).
- 제목 번개는 켜져 있으면 진한 블루(`DS.accent`)다.
- 버튼은 `NotchFocusView.activateRequest/deactivateRequest` 알림으로 앱의 `KeepAwakeController`를 부르고, 컨트롤러는
  모든 이벤트 뒤 `didChangeNotification`을 보내 위젯·메뉴·띠 물범이 함께 바뀐다. 사운드·HUD는 메뉴와 같다.

### Timer 모드

같은 다이얼(`FocusDial`)에 눈금만 분이다: 0~60분, 15·30·45분에 점, 오른쪽 끝 "60m"(`TimerPolicy.dialMaxLabel`).
Keep Awake와 같은 12칸이라 5분 × 12 = 1시간이 끝이다(`TimerPolicy.lengthRange` 5~60분, 메뉴 프리셋 최댓값과 같다).

- 꺼짐: 호를 끌면 5분 눈금(`dialLength(fraction:)`, 아래 빈 곳은 가까운 끝)으로 맞추고 한 칸마다 햅틱. 가운데에는 20pt 고른 길이("25m")와
  블루 10pt "Start". 마지막 길이는 `ChapTimerLength`(기본 25분, 1시간을 넘는 2.14 저장값은 기본값으로). VoiceOver 조절 동작은 5분씩.
- 돌 때: 남은 시간까지 호가 1초마다 줄어든다(같은 0~60분 눈금). 가운데에는 18pt 남은 시간(`TimerPolicy.clockLabel`, `m:ss`)과
  10pt "Stop"(마우스를 올리면 빨강). 안쪽 원을 누르면 멈춘다.
- 버튼은 `NotchFocusView.timerStartRequest/timerStopRequest` 알림으로 `ChapTimerController`를 부른다. 타이머는 한 번에 하나, 메모리에만,
  Keep Awake와 따로 돈다(Mac을 깨워 두지 않는다).
- 끝나면 Glass 소리와 HUD "Time's up"(노치 화면, 없으면 커서 화면). 끝나는 시각은 벽시계 기준이라 잠든 시간도 센다.

## 접는 선반 칸 (Screenshots · Downloads)

- 선반 칸 제목 줄 오른쪽 끝의 접기 버튼(`chevron.up`, 칸에 마우스를 올렸을 때만 보임)이나 제목의
  우클릭 "Collapse"로 칸을 접는다. 접힌 칸은 위젯 줄에서 빠지고 **검정 띠 왼쪽**에 흰 아이콘으로 놓인다
  (위 "상단 띠 왼쪽"). 아이콘을 누르면 원래 자리에서 다시 펼쳐진다.
- **도커 폭**: 접으면 도커는 남은 칸에 맞춰 양쪽이 같이 줄어든다(최소 폭 `dockMinWidth`까지). 최소 폭이
  검정 띠(노치 + 좌우 상태 영역 110pt씩 + 곡선 90pt)를 늘 감싸고, 띠 아이콘·물범은 노치 기준이라 제자리다.
  창은 커질 때 바로, 작아질 때는 칸 애니메이션 뒤(0.26초, `NotchLauncherPolicy.resizeSteps`/`shrinkDelay`)
  맞춰 내용이 창 밖으로 잘리지 않는다. 펼칠 때는 칸 폭 + 간격만큼 창을 먼저 넓히고(`preExpandSize`) 다음 틱에
  칸을 펼친다. 같은 틱에 바꾸면 넓어진 도커 양 끝이 좁은 창에 잘려 노치가 접혔다 펼쳐지는 것처럼 끊겨 보였다.
- 새 파일 개수 같은 배지는 달지 않는다(BRAND: 관심을 조르지 않는다).
- 접힌 목록은 `Config.notchCollapsedWidgets`에 저장한다. 노치에서만 바꾸는 이 Mac의 표시 선택이라
  설정창 저장이 덮어쓰지 않는다.
- **어깨 영역**: 검정 띠가 plateau 바깥에서 곡선(`stripFalloff` 90pt)으로 얇아진 뒤 도커 양 끝까지 남는
  밝은 띠는 비워 둔다. 렌더 도구와 Debug 빌드(`defaults write com.mingyupark.Chap ChapShowShoulderGuides -bool YES`)
  에서 경계선(빨강 어깨, 주황 곡선, 파랑 plateau)으로 확인할 수 있다.

## 선반 스크롤 (Screenshots · Downloads)

두 선반은 최근 12개까지 담고(`maxItems`), 목록 칸 4줄 높이(113pt, `visibleRows` 4)에 고정된
`NotchShelfScrollList`에 그린다. 5개 이상이면 트랙패드·휠로 스크롤한다.

- 스크롤바는 `.scrollIndicators(.never)`로 시스템 "스크롤 막대 항상 보기" 설정에서도 숨긴다.
- 더 있음을 알리는 신호는 맨 아래 10pt 흐림 하나뿐이다. 콘텐츠 아래에 같은 10pt 여백이 있어
  끝까지 내리면 마지막 줄이 흐림 밖으로 올라온다. 4개 이하이면 흐림도 스크롤도 없다.
- 줄은 `LazyVStack`이라 보이는 줄의 썸네일·아이콘만 먼저 읽는다.

## Downloads 칸

`~/Downloads`에서 최근 12개(폴더에 들어온 시각 순, 없으면 수정 시각)를 담고 4줄이 보인다. 나머지는 스크롤로 본다(위 "선반 스크롤"). 숨김 파일, 받는 중인 파일
(`.crdownload`, `.download`, `.part` 등), 폴더(.app 제외)는 뺀다(`DownloadsShelfPolicy`). 한 줄은 26pt: 20pt 파일
아이콘(이미지는 썸네일), 가운데 생략 파일명, 오른쪽 끝 짧은 시각(`now`, `5m`, `3h`, `1d`, `Sep 24`). 클릭 열기, 드래그
꺼내기, 우클릭 Open·Share…·Show in Finder. 제목 클릭은 Finder로 다운로드 폴더를 연다. 2초마다 다시 읽고, 위젯이
보일 때만 읽는다. macOS가 다운로드 폴더를 보호하므로 처음 한 번 폴더 접근 권한을 묻는다.

**잘린 파일명 보기**: 파일명이 줄 안에서 잘린 줄(`DownloadsShelfPolicy.needsFullName`, 실제 10pt 글꼴 폭과
보이는 폭 비교)에 0.35초 머물면, 그 이름 자리에 겹쳐 전체 파일명 말풍선이 뜬다(macOS 확장 툴팁 방식).
글자 시작(줄 왼쪽에서 32pt)에 맞추고, 어두운 바탕(검정 86%)에 흰 10pt라 Mist·Glass에서도 대비가 같다.
최대 320pt, 넘으면 두 줄. 스크롤 목록 밖(칸)에서 그려 목록 잘림·아래 흐림에 가리지 않고, 칸 오른쪽 밖으로
뻗을 수 있다. 누를 수 없고(아래 줄 클릭 그대로) VoiceOver는 줄 라벨로 전체 이름을 읽는다. 잘리지 않은 이름은 띄우지 않는다.

## 타이머 배지

**접힌 노치의 타이머 배지**: 타이머가 돌고 도커가 접혀 있으면 노치 왼쪽에 남은 시간 배지(`NotchTimerBadgeView`, `NotchLauncherPolicy.timerBadgeFrame`)가 붙는다. Drop 배지를 좌우로 뒤집은 모양으로, 오른쪽 18pt는 노치 밑으로 겹치고 본체 52pt, 왼쪽 플레어로 메뉴 막대에 합류한다. 12pt semibold rounded 흰 숫자, 마지막 1분은 `accentLight`. 도커를 닫을 때는 닫힘 애니메이션이 시작되는 즉시 배지를 패널보다 위에 올려, 접히는 검정 띠에서 끊기지 않고 이어진다. 마우스를 올리면 도커가 열리고, 열린 동안 배지는 숨는다(Keep Awake 칸의 Timer 모드가 남은 시간을 보여 준다). 노치가 없는 화면에는 두지 않는다(I16). 노치 런처가 꺼져 있어도 메뉴 Timer는 쓸 수 있다.

## Launchers 칸

위젯 칸(3~6번)에 놓는 Sites·Finder 목록 묶음(`NotchWidget.launchers`, `NotchLaunchersTabSlot`). 따로 두던 Sites·Finder 위젯은 2.16에서 없앴다. 폭은 112–170pt 안에서
모든 탭의 가장 넓은 내용과 제목 + 탭 아이콘 중 큰 쪽(`LauncherListPolicy.launcherTabsColumnWidth`, 가장 긴 제목이 골라졌을 때의 제목 줄 기준). 둘 다 이름 + 키캡 목록이라 어느 탭이든
칸이 같은 모양으로 찬다. Apps는 아이콘 격자라 넣지 않는다: 탭을 바꿀 때 목록 폭에 격자가 들어가
양옆이 비었다(2.15.0–2.15.2). Apps는 Layouts와 함께 Apps 칸에 둔다(`LauncherListPolicy.launcherTabTypes`).

- 제목 줄이 곧 탭이다(`▢ Sites  ▤`, launch type 순서 고정). 고른 탭만 아이콘 + 이름
  (`NotchTabTitle`, 다른 칸 제목과 같은 모양)이고, 나머지는 흐린 아이콘(22pt)만 둔다. 면·밑줄은 없다.
  아이콘을 누르면 그 탭으로 바꾼다. 고른 탭의 이름은 누를 수 없는 머리글이고, 마우스를 올리면 뒤에 ›(18pt 버튼)가
  보여 그것만 그 타입의 설정을 연다. 탭을 바꾸려다 이름을 눌러 설정창이 뜨던 일을 막는다(2.16.0까지는 이름 전체가 버튼).
  › 자리는 늘 잡혀 있어 칸 폭은 그대로다. 탭 없는 칸(Screenshots·Downloads·Keep Awake 등)의 제목은 그대로 버튼이다.
  같은 아이콘을 제목과 탭에 두 번 그리지 않아 제목 줄이 짧다. 타입이 하나뿐이면 제목만 남는다.
- 제목 줄 오른쪽 빈 자리 전체가 옆 탭 버튼이다(`TabStepPolicy.neighbor`, 두 탭이면 늘 다른 쪽). 22pt 아이콘을 겨냥하지
  않아도 되고, 마우스를 올리면 갈 탭 아이콘이 진해진다. 보이는 것은 없어 칸 모양은 그대로다.
- 트랙패드 두 손가락 가로 스와이프로도 넘긴다(Launchers·Apps 칸, Keep Awake 칸의 Keep Awake ↔ Timer 공통, `tabSwipe`, `TabSwipeTracker`). 왼쪽으로 밀면 다음
  탭, 오른쪽이면 이전 탭(손가락 기준, 자연스러운 스크롤 설정과 무관). 제스처 하나에 한 칸만, 문턱 24pt, 관성은 무시한다.
  가로가 세로의 1.5배를 넘을 때만 반응하고 그때만 이벤트를 삼켜 선반의 세로 스크롤과 섞이지 않는다. 칸 위에 마우스가 있는
  동안만 `NSEvent` 로컬 모니터(공개 API)를 건다. 정밀 스크롤(트랙패드·Magic Mouse)만 다루고 일반 휠은 그대로 둔다.
  끝에서 더 밀면 본문이 그 방향으로 6pt 튕기기만 한다.
- 탭을 바꾸면(클릭·빈 자리·스와이프 모두) 넘기는 방향으로 본문이 14pt 밀려 나가고 들어오며 페이드한다(`NotchTabMotion`).
- 본문은 이름 + 키캡 목록이다. 목록 칸 4줄 높이에 고정하고 폭을 모든 탭 기준으로 잡아, 탭을 바꿔도 바닥선과 폭이 그대로다.
- 탭 칸(Launchers·Apps)은 제목 줄 아래를 6pt 더 띄운다(`NotchAppIconTile.tabBodyTopGap`). To-do 칸(제목 줄 21pt + 4pt)과
  본문 시작이 같아(16 + 3 + 6 = 25pt), 목록 줄(26pt, 간격 3pt)이 To-do 줄과 같은 높이에 놓이고 4줄이 위아래 같은 여백으로 찬다.
  목록 줄은 To-do·Downloads처럼 26pt로 고정한다(글자 높이에 맡기면 25pt 안팎이라 아래가 남았다). Layouts 타일은 줄 간격을
  0으로 둬(타일 위아래 여백 2pt씩) 두 줄이 다른 칸 바닥선 안에 든다.
- 마지막 탭은 UserDefaults `ChapLauncherTab`에 기억하고, 그 타입이 비면 첫 타입(`LauncherListPolicy.selectedTab`).
  탭을 바꿀 때 햅틱(`.alignment`).
- 항목이 하나도 없으면 칸을 그리지 않는다(빈 런처 칸과 같은 규칙).

## Layouts 탭

Apps 칸의 두 번째 탭으로 보는 로컬 창 배치 격자(`NotchLayoutsView`, 폭 108pt, 타일 48pt: 묶음 사이를 Apps 탭처럼 촘촘하게 두고 긴 이름은 끝을 줄인다, 툴팁에 전체 이름). 2.16 전에는 따로 놓는 Workspaces 위젯이었다(2.17 다음 릴리스에서 이름을 Layouts로 바꿨다). 2열 타일이며, 최대 4개라 2×2에 맞는다. 타일은 그 Layout 앱 아이콘을 앞에서부터 넷까지 모은 32pt 묶음(`LayoutIconCluster`, Apps 탭 앱 아이콘과 같은 크기, 줄 간격 8pt, 폴더 아이콘처럼 둘씩 줄지어, 하나면 크게 하나)과 아래 10pt 이름이다. 같은 앱 조합이 겹칠 수 있어 이름은 늘 보인다. 마우스를 올리면 이름과 앱 목록 툴팁, 열리는 중에는 묶음 위에 진행 표시가 돈다. 줄을 누르면 도커를 접고 `LayoutRestoreService`가 뒤쪽 창부터 앱을 열어 저장된 배치를 적용한다. 가능하면 마지막에 캡처 당시 앞쪽 앱이 활성화된다.

4개 미만이면 빈 자리에 점선 `+` Capture 타일이 보이며, 누르면 도커를 접고 `Capture Layout` 창을 연다. Layout은 `~/Library/Application Support/Chap/Layouts.json`에만 저장되고 config Import/Export에는 포함하지 않는다. 앱 이름·창 제목·디스플레이 UUID·visibleFrame 상대 프레임을 저장한다. 연결했던 화면이 없으면 커서 화면에 같은 상대 프레임을 맞춘다.

캡처 대상은 위치·크기 변경이 가능한 표준, 비최소화, 비전체화면 앱 창이다. 앱당 focused 표준 창 또는 유일한 표준 창 하나만 제안하며 여러 창 중 하나를 증명할 수 없으면 제외한다. 복원은 저장한 제목과 정확히 하나가 맞는 창, 없으면 표준 창이 하나일 때 그 창, 그것도 없으면 포커스된 표준 창에 적용한다(최소화된 창은 Dock에서 꺼내서). 앱의 최소 크기보다 작게 저장된 창은 그 크기로 키우되 화면 안에 둔다(`LayoutGeometry.bounds(minimumSize:)`). 앱마다 12초 상한이라 한 앱이 멈춰도 다음 앱은 열리고, 끝나면 자리를 못 잡은 앱 이름을 알려 준다. 열리는 동안 `LayoutLibrary.busyID`가 설정 버튼과 노치 줄을 진행 표시로 바꾸고 한 번에 하나만 돈다. 최대 Layout 4개·Layout당 창 6개다.

고른 Layouts 탭 이름 뒤 ›를 누르면 도커를 접고 설정창 Launchers의 Layouts 섹션을 연다. 저장된 Layout이 있으면 첫 번째를, 없으면 섹션만 고른다(`AppDelegate.showLayoutsInSettings`). 줄을 우클릭하면 Open / Edit… / Remove…가 있다. Edit…은 설정창 Launchers 탭의 Layouts 섹션에서 그 Layout을 연다(`SettingsView.focusLayout`). 그곳에서 이름·창별 디스플레이·창 빼기를 바로 저장하고(`LayoutStore.replacing`, 자리·id 유지), Update Positions로 지금 창 위치를 다시 읽는다(`ChapLayout.updatingPositions`, 같은 앱만 갱신). Remove…는 도커를 접은 뒤 확인 창을 띄운다(설정의 Remove와 같은 경로). VoiceOver는 줄의 Edit·Remove 동작을 쓴다.

캡처 창에서는 모니터가 둘 이상이면 줄마다 디스플레이 캡슐(`LayoutDisplayMenuButton`)이 보이고, 누르면 연결된 디스플레이와 Follow Cursor 중에서 고른다. 바꿔도 창의 상대 위치·크기는 그대로다(`LayoutWindow.assigned(to:)`). 같은 이름의 모니터는 `LayoutDisplay.menuLabels`가 번호를 붙여 구분한다. Follow Cursor는 디스플레이를 비워 저장하고 열 때 커서 화면에 맞춘다. 모니터가 하나면 캡슐 없이 둘째 줄에 디스플레이 이름만 보인다. 미니맵의 창 사각형은 틀 안쪽 3pt 여백 안에만 그려 화면 끝에 붙은 창도 테두리가 겹치지 않는다.

## To-do 칸

위젯 칸(3~6번)에 놓는 짧은 체크리스트(`NotchWidget.todo`, `NotchTodoView`, 폭 140–240pt).
폭은 저장된 항목 중 가장 긴 줄에 맞추되(`NotchTodoView.columnWidth`, `TodoColumnPolicy`) 도커를 열 때 한 번 정한다.
열려 있는 동안 추가·수정·삭제해도 폭은 그대로이고 다음에 열 때 반영된다. 가운데 정렬 도커가 입력·삭제마다 흔들려 다른 칸이
마우스 아래에서 비켜나지 않게 하기 위해서다. 항목 문구는 메모리(`NotchTodoView.knownTitles`)에 두고, 노치 런처를 켤 때
직렬 큐에서 미리 읽어(`preloadTitles`) 첫 도커도 맞는 폭으로 열린다. 240pt를 넘는 문구는 말줄임한다. Chap 안에만 저장한다
(`TodoStore`, `~/Library/Application Support/Chap/Todos.json`, 권한·동기화 없음, 설정 Export/Import에 안 섞임).

- 미니멀: 면·캡슐·진행선 없이 글자와 동그라미만 둔다. 줄 배경은 마우스를 올린 줄에만 생긴다.
  제목 줄은 다른 칸처럼 아이콘 + "To-do"와 오른쪽 보조색 "2 left"(다 끝나면 "Done") 한 단어뿐이고,
  완료 항목이 있으면 칸에 마우스를 올렸을 때만 그 앞에 블루 "Clear"가 나온다(누르면 잠시 "Undo").
- 줄: 다른 목록과 같은 26pt, 16pt 체크 동그라미(완료는 보조색 `checkmark.circle.fill`) + 12pt 문구(`DS.notchRowName`).
  완료 항목은 색을 칠하지 않고 흐린 보조색 + 취소선으로만 구분한다. 최대 4개(`maxItems`)라 항목 + 추가 줄이 늘 4줄 이하로, 스크롤 없이 목록 칸 높이(113pt)에 맞는다.
- 추가: 맨 아래 `+ Add to-do` 줄은 면 없이 흐린 글자로 늘 보여 빈 자리의 용도를 알 수 있다. 마우스를 올리면 글자와 ＋가
  블루로 바뀐다. 입력 중에는 커서가 위치를 알려 주므로 따로 테두리를 두지 않는다. 줄을 누르면 바로 입력. Enter로 더하고 같은 줄에서 다음
  항목을 이어 쓴다. 칸 밖 클릭(`didClickPanel`), 다른 앱, Esc, 패널 닫힘이면 쓰던 문구를 확정하고 입력을 닫는다.
  문구는 한 줄로 다듬고 200자까지(`cleanedTitle`), 빈 문구는 버린다. 4개가 차면 추가 줄을 숨기고, 완료 항목을 지우면(Clear Completed·Delete) 다시 보인다.
- 완료: 동그라미를 누르면 체크·취소선. 항목은 제자리에 있다(아래로 옮기지 않는다, `ordered`는 넣은 순).
- 수정·삭제: 문구 더블클릭으로 고치고(비우면 삭제). 줄에 마우스를 올리면 줄이 옅게 강조되고 오른쪽 끝에 16pt ×
  (`TodoDeleteButton`, 보조색, 버튼에 올리면 `DS.danger` 원)가 나타나 바로 지운다. 숨어 있을 때도 자리를 잡아 문구가
  밀리지 않는다. 우클릭에 Mark Done/Edit/Delete, VoiceOver는 줄의 Delete 동작. 제목 우클릭 → Clear Completed.
- 제목 오른쪽 상태 캡슐은 `2 left`처럼 남은 수를 글자로 보여 주고, 완료 항목이 있으면 같은 캡슐 안에 `Clear`를 묶는다.
  제목 아래 2pt 진행선(`TodoProgressBar`, `TodoStore.progress`)이 끝낸 비율만큼 블루로 찬다. 색만으로 상태를 전하지 않고,
  열린 노치 안에서만 보여 닫힌 노치·메뉴 막대에는 배지를 달지 않는다.
- 체크하는 순간: 동그라미가 체크로 바뀌며 한 번 튀고(`.symbolEffect(.bounce)`), 문구의 대비가 낮아지고 취소선이 생긴다.
  트랙패드 햅틱(`.levelChange`)과 함께 `NotchTodoView.didCompleteNotification`을 보내
  검정 띠의 물범이 꼬리를 한 번 까딱한다(동작 줄이기·닫힌 노치에서는 까딱하지 않음). 체크를 풀 때는 조용하다.
- 비었을 때: 첫 줄 "Add to-do"만 두면 아래 세 줄이 비어 허전하다. "All done."과 같은 구도로 가운데에 흐린 `checklist` 아이콘,
  보조 문구 "Nothing on your plate.", 액센트 캡슐 "Add to-do"를 둔다. 빈 칸 어디를 눌러도 입력이 시작되고, 그때 첫 줄에
  입력칸이 열리는 목록으로 짧게 페이드해 바뀐다. 본문 높이(113pt)는 그대로라 바닥선이 다른 칸과 같다.
- 다 끝냈을 때(`isAllDone`): 목록 대신 블루 체크, "All done.", 캡슐 둘. "Back"은 목록으로 돌아가 체크를 풀 수
  있게 하고, "Clear"는 완료 항목을 비운다. 끝낸 항목이 하나라도 있으면 제목 줄 오른쪽에 작은 "Clear"가 있어
  Back으로 돌아온 뒤에도 상태 캡슐의 "Clear"로 바로 비운다. 저절로 지우지는 않는다. 축하는 이 정도로만 한다.
- 비우기 되돌리기: "All done." 화면의 Clear는 마무리라 바로 빈 화면("Nothing on your plate.")으로 돌아가고 되돌리기를 남기지
  않는다(다시 보려면 그 전에 Back). 목록에서 일부만 비울 때(제목 줄 Clear·Clear Completed)는 목록이 바로 비고
  4초 동안 제목 줄 오른쪽 `Undo` 캡슐로 되돌릴 수 있다(`restoring`, 그사이 넣은 항목은 지키고 4개 한도 안에서 되돌림). 노치를 닫으면 되돌리기도 끝난다. 줄 하나를 Delete한 것은 되돌리지 않는다.
- 이전 버전은 모르는 위젯 이름을 버리므로 `todo` 칸은 그냥 빈 칸이 된다(설정은 그대로 읽힌다).

## Quick Note 창

- 상단 띠의 메모 아이콘은 도커를 접고(`requestClose`) Quick Note 창(`QuickNoteWindow`, floating, 크기 조절 가능)을 연다.
  도커 안 메모 모드는 없다.
- 열 때마다 창 윗변을 노치 아랫변에 붙이고 노치 가운데에 맞춘다(`QuickNotePlacement.origin`, 보이는 영역 밖이면 안으로
  당김). 그다음엔 자유롭게 옮긴다. 크기는 `ChapQuickNoteWindow` frame autosave로 기억하고 자리는 기억하지 않는다.
  노치 화면이 없으면 커서 화면 가운데.
- ⌥N도 같은 동작이다. 키는 Settings → Tools → Quick Note에서 바꾸거나 비워서 끈다. 노치 런처·띠 아이콘 상태와
  무관하게 등록된다(노치 없는 Mac도 ⌥N으로 메모를 연다). 노치 런처와 Quick Note 아이콘이
  켜져 있을 때만 등록하고, 같은 키를 사이트가 쓰면 사이트가 우선이며 설정창에 빨간 안내가 뜬다.
- 창이 열려 있을 때 아이콘을 다시 누르면 그 창을 앞으로 가져온다(편집기는 하나).
- 도구 줄: 제목·글자 수·복사·Show Backups(백업 폴더를 Finder로).
- ⌘Z로 입력을 되돌리고 ⇧⌘Z로 다시 한다. 앱의 숨은 Edit 메뉴(`AppMainMenu`)가 단축키를 메모 상자로 보낸다.
- **Esc로 닫는다**(`QuickNoteWindow.handleKeyDown`, local key monitor). 메모 상자에서 타이핑 중이어도 TextEditor보다
  먼저 받아 삼킨다. 닫힘 경로가 하나(`willClose`)라 Esc로 닫아도 마지막 입력이 flush되어 저장된다.

## Quick Note 저장

- 입력하면 0.5초 뒤 저장한다(`SaveDebouncer`, 직렬 큐). 다만 **커서가 풀리는 순간 기다리지 않고 바로 저장**한다
  (`isFocused`가 false가 되면 flush).
- 커서가 풀리는 경우: 노치 패널 안에서 메모 상자 밖을 누름(`didClickPanel`의 클릭 좌표가 상자 밖), 패널이 key를
  잃음(다른 앱·바탕 클릭), 메모 상자 밖 빈 곳 탭, 메모 창(`QuickNoteNSWindow`)이 key를 잃음, 창 닫기(Esc·닫기 버튼).
- 상자 오른쪽 아래 10pt 표시: 입력 중 아직 안 쓰였으면 "Editing", 저장되면 "Saved · 6:12 PM"(오늘) /
  "Saved · Oct 4, 6:12 PM"(올해) / "Saved · Oct 4, 2025, 6:12 PM"(`QuickNoteStore.savedLabel`). 빈 메모는 표시 없음.
  저장이 실패하면 "Couldn't save"(입력은 화면에 남는다).
- 백업(`QuickNoteBackupPolicy`): 덮어쓰기 직전 이전 내용을 `QuickNote Backups/QuickNote-yyyyMMdd-HHmmss.txt`로 남긴다.
  평소엔 10분에 한 번, 40자 이상 메모가 절반 넘게 줄면 바로. 빈 메모·같은 내용은 남기지 않고, 최신 10개만 둔다.
  백업 실패는 저장을 막지 않는다.
- 읽기 실패(`QuickNoteStore.loadResult`): 파일이 있는데 UTF-8이 아니면 원본을 백업 폴더의
  `QuickNote.unreadable-<시각>.txt`로 옮기고(개수 정리 대상 아님) 빈 메모로 시작하며 안내를 띄운다. 파일을 열지도
  옮기지도 못하면 편집을 막아 원본을 덮어쓰지 않고, 다음에 열 때 다시 읽는다.

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
- `Sources/ChapCore/MirrorPolicy.swift`, `QuickNoteStore.swift` — 거울 상태·메모 저장 (테스트로 고정)
- `Sources/Chap/Views/NotchStripToolsView.swift`, `NotchQuickNoteView.swift`, `Sources/Chap/MirrorCamera.swift` — 띠 도구(거울·메모·Cover Screens)
- `Sources/Chap/Views/NotchFocusView.swift`(칸·모드 탭·Keep Awake 모드), `NotchFocusTimerBody.swift`(Timer 모드), `NotchFocusDial.swift`(다이얼), `NotchMascotView.swift`, `NotchWidgetViews.swift` — Keep Awake 칸·물범·위젯 공용
- `Sources/Chap/Views/NotchLauncherPanelView.swift`, `NotchDockShapes.swift`, `NotchSlotModel.swift`, `NotchLauncherRows.swift` — 메인 패널·도커 실루엣 셰이프·칸 모델·런처 줄
- `Sources/Chap/Views/NotchLayoutsView.swift`, `LayoutCaptureView.swift` — Layout 노치 탭 격자·캡처 확인 창
- `Sources/Chap/Layouts/`, `Sources/ChapCore/Layout*.swift` — AX 캡처·복원, 정규화 좌표·로컬 저장
- `Sources/Chap/Views/NotchDropViews.swift` — Drop 도커·드롭 존·배지
- `Sources/Chap/NotchLauncherController.swift` — 창 배치·표시 로직
