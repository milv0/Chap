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
  plateau 안에 파란 번개(bolt.fill) 아이콘 + h:mm:ss 남은 시간을 1초마다 렌더링한다.
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
| `awakeStatusOffsetX` | -2 | 왼쪽 상태 영역 안의 h:mm:ss 번개+시간 묶음 좌측 광학 보정 |
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
| Sites·Finder | 가장 긴 줄(이름 + 키캡)과 제목 중 긴 쪽, 112–170pt (`LauncherListPolicy.listColumnWidth`) |
| Screenshots | 썸네일 34 + 가장 긴 시각 문구 기준, 112–170pt |
| Apps | 2열 아이콘 격자 80pt (제목이 더 길면 제목 폭) |
| Downloads | 200pt (12pt 파일명, 20자 안팎) |
| Focus | 116pt (80pt 링 + 길이 칩 셋) |
| To-do | 170pt (12pt 문구, 20자 안팎) |

글자 폭은 `NotchTextMetrics`가 실제 글꼴(13pt 본문, 11pt semibold)로 재고 SwiftUI 렌더링 여유를 더한다. 위젯 종류(Sites·Apps·Finder·Screenshots)가
모두 한 번에 들어가는 수라서 페이지를 두지 않는다. 2.1의 12칸 설정은 뒤쪽 위젯을 앞쪽 빈 칸으로
당겨 6칸에 옮기고, 2.0의 4칸 설정은 순서 그대로 앞 4칸이 된다.

**선반 칸 고정**: 앞 두 칸은 선반 자리로 주인이 정해져 있다. 1번 칸 Screenshots, 2번 칸 Downloads
(`NotchWidget.shelfSlots`, `fits(slot:)`). 다른 위젯은 3~6번 칸에만 놓인다. 선반은 접으면 검정 띠 **왼쪽** 아이콘이
되므로 펼쳐지는 자리도 늘 맨 왼쪽이어야 아이콘과 칸이 같은 쪽에 있다. 설정 보드의 선반 칸(`ShelfSlotToggle`)은 자물쇠가
달린 켜기/끄기 버튼이라 끌어 옮기거나 서로 바꾸거나 다른 위젯을 놓을 수 없고, 팔레트에도 선반이 없다. 이전 배치는 읽을
때 선반을 고정 칸으로 옮기고 나머지 순서(빈 칸 포함)는 그대로 둔다(`normalizedSlots`). 기본 배치는 Screenshots · 빈
Downloads 칸 · Sites · Apps · Finder · 빈 칸.

## Apps 칸: 아이콘 격자

Apps 위젯은 목록 대신 앱 아이콘 2열 격자(최대 2열 × 3줄, 6개)다. 앱 수와 관계없이 2열 × 3줄 자리(113pt)를 잡고 위에서부터 한 줄에 둘씩 채운다. 아이콘 32pt, 타일 34pt 정사각(고정 폭 열), 가로 간격 8pt, 세로 간격 5.5pt. 세로 간격은 격자 3줄(앱 6개) 높이가 목록 칸 4줄 높이(26pt × 4 + 3pt × 3 = 113pt)와 정확히 같도록 계산한다.
단축키가 있으면 아이콘 오른쪽 아래에 키 글자만(`S`) 10pt semibold 키캡으로 붙인다. 호버 시 앱 이름
툴팁과 `rowHoverBackground`, VoiceOver는 "Launch Slack, Option S". 아이콘은 `AppIconLoader`가
utility queue에서 `NSWorkspace.icon(forFile:)`로 읽고 경로별로 캐시한다. Apps 칸 폭은 격자 폭 80pt다. 목록 칸(Sites·Finder 등)은 160pt 그대로다.

## 상단 띠 왼쪽: 접힌 선반 · 마스코트

노치 왼쪽 검정 띠(`stripPlateauSideWidth` 110pt)에는 접힌 선반 아이콘과 Chap(아기 물범 마스코트, 이름이 곧 Chap이다,
`ChapMascot` 24×12 픽셀 × 1.5pt = 36×18pt)가 놓인다. Focus 남은 시간은 더 이상 띠에 그리지 않는다
(Focus 칸과 상태 메뉴에서 본다). 시계 코드는 `awakeStripClock`·`StripLeading.focusClock` 주석으로 남겨 두었다.

물범 자리는 Focus 칸이 보이든 아니든 **늘 띠 왼쪽이다**(`NotchLauncherPolicy.stripLeading()`). Focus 칸은 번개와
남은 시간을 맡고, 물범은 띠에서 Focus 상태를 보여 준다.

| Focus 세션 | 띠 물범 |
|---|---|
| 꺼짐 | 엎드려 쉼. 눈 뜸, 가끔 까딱(7~12초), 깜빡임 |
| 켜는 순간 | 첨벙 다이빙 한 번(아래 "Focus 다이빙") 뒤 원래 자리로 |
| 30분 이상 남음 | 꼬리를 0.4초 프레임으로 계속 흔듦 |
| 30분 미만 | 졸린 눈꺼풀(`Eyes.drowsy`), 꼬리를 0.7초 프레임으로 느리게 흔듦 |

- **접힌 선반 아이콘**: 흰 13pt(`DS.notchStripIconColor`, 호버 100%), 오른쪽 띠 도구와 노치를 기준으로
  대칭인 자리(노치 왼쪽 끝에서 13pt, 41pt, `leftStripIconCenterOffsets`). 왼쪽에서 오른쪽으로 칸 순서가
  읽히도록 마지막 칸이 노치에 가장 가깝다. 메모 모드에서는 숨긴다.
- **물범 자리**: 아이콘이 없으면 왼쪽 상태 영역 가운데(노치에서 55pt), 있으면 바깥쪽으로 비켜 86pt
  (`stripMascotCenterOffset`). 아이콘 두 개(노치에서 55pt까지)와 물범(68~104pt)이 겹치지 않는다.

마스코트는 `Canvas`로 픽셀마다 사각형을 칠하며, 누를 수 없고 VoiceOver에서 제외된다.
꼬리 까딱: 도커가 펼쳐지고 0.35초 뒤 한 번(`flickSequence` 들기·내리기 ×2, 프레임 0.14초),
이후 열려 있는 동안 7~12초 무작위 간격으로 반복한다. 꼬리 프레임(`tailUpRows`)은 오른쪽 끝 다섯 칸만 다르다.
`.task(id:)`가 `reveal.revealed`에 묶여 닫히면 취소되고, 동작 줄이기(Reduce Motion)가 켜져 있으면 움직이지 않는다.
깨어 있는 동안 4~7초마다 0.15초 깜빡인다(`Eyes.closed`).

**Focus 다이빙(몰입)**: Focus가 켜지는 순간(꺼짐 → 켜짐, 노치가 열려 있을 때) 띠 물범이 첨벙 다이빙을 한 번 한다
(`ChapMascot.focusDiveSequence`, 10프레임 × 0.1초 = 1초): 웅크림(아래 1px) → 꼬리를 들고 뛰어오름(위 3px) → 물이 차오르며
첨벙 뛰어들어 잠깐 잠김(아래 3·5px) → 꼬리를 들고 튀어 올라 첨벙 → 물이 빠지고 원래 자리. 물범은 열마다 수면(`surfaceRow`)보다
아래 부분을 그리지 않아 물속으로 들어간 모습이 된다. 물은 다이빙하는 동안만 있고, 그 뒤에는 물 없이 원래 자리에서 꼬리를 흔든다.
(물에 떠서 헤엄치기와 끝까지 잠수하기도 해 봤지만 유치하거나 상태가 안 보여 뺐다.) 이미 켜진 채 노치를 열거나 동작 줄이기·
닫힌 노치에서는 다이빙하지 않는다. 물은 물범 위에 그리는 겹침 레이어라 수면은 제자리이고 물범만 뛰고 가라앉는다.
물속 `#2440AA`, 마루 `#6E91FF`, 물방울 `#A0B9FF`.
띠에서는 z가 화면 위 경계에 잘리므로 잠든(`.asleep`) 모습 대신 쉬는 자세를 쓴다. `.asleep`·z·`widgetPixelSize`(2pt)는
`ChapMascot`에 남아 있다(2.5.0의 Focus 칸 물범). 꼬리 흔들기 속도는 `focusWagFrameDuration(for:)`.
배경 위 투명 도커로 근사한다. 변수 없이 테스트하면 건너뛴다.

## Focus 칸 (Keep Mac Awake)

번개 아이콘의 Focus 모드. 상태바 메뉴 Keep Mac Awake와 **같은 세션**이다.
- 물범은 칸이 아니라 검정 띠에 있다(위 "상단 띠 왼쪽").
- 켜고 끄는 모습이 같은 **하나의 링**이다(지름 80pt, 두께 5pt, `FocusRing`, 칸 폭 116pt). 링 전체가 버튼이다.
- 꺼짐: 빈 링(본문색 12%) 가운데 블루 번개와 "Chap on". 마우스를 올리면 링이 연한 블루로 차오르고, 누르면
  `FocusPressStyle`로 눌렸다 튀어 오르며 트랙패드 햅틱(`.levelChange`, 권한 없음)이 온다. 링 아래에 길이 칩 1h·4h·8h
  (30×18pt 캡슐, 고른 칩은 블루 테두리·글자, 마지막 선택을 `ChapFocusPresetDuration`에 기억, 기본 1h).
- 켜짐: 같은 링이 남은 비율만큼 블루 호로 12시 방향부터 차 있다가 1초마다 줄어든다(`focusProgress`, 길이를 모르면
  `inferredFocusDuration`). 가운데 15pt 남은 시간(h:mm:ss). 링 아래 문구는 두지 않는다(링과 숫자로 충분하다). 마우스를 올리면 가운데가
  "Chap off"로 바뀌고, 누르면 끈다.
- 제목 번개는 켜져 있으면 진한 블루(`DS.accent`)다.
- 버튼은 `NotchFocusView.activateRequest/deactivateRequest` 알림으로 앱의 `KeepAwakeController`를 부르고, 컨트롤러는
  모든 이벤트 뒤 `didChangeNotification`을 보내 위젯·메뉴·띠 물범이 함께 바뀐다. 사운드·HUD는 메뉴와 같다.

## 접는 선반 칸 (Screenshots · Downloads)

- 선반 칸 제목 줄 오른쪽 끝의 접기 버튼(`chevron.up`, 칸에 마우스를 올렸을 때만 보임)이나 제목의
  우클릭 "Collapse"로 칸을 접는다. 접힌 칸은 위젯 줄에서 빠지고 **검정 띠 왼쪽**에 흰 아이콘으로 놓인다
  (위 "상단 띠 왼쪽"). 아이콘을 누르면 원래 자리에서 다시 펼쳐진다.
- **도커 폭**: 접으면 도커는 남은 칸에 맞춰 양쪽이 같이 줄어든다(최소 폭 `dockMinWidth`까지). 최소 폭이
  검정 띠(노치 + 좌우 상태 영역 110pt씩 + 곡선 90pt)를 늘 감싸고, 띠 아이콘·물범은 노치 기준이라 제자리다.
  창은 커질 때 바로, 작아질 때는 칸 애니메이션 뒤(0.26초, `NotchLauncherPolicy.resizeSteps`/`shrinkDelay`)
  맞춰 내용이 창 밖으로 잘리지 않는다. 펼칠 때는 칸 폭 + 간격만큼 창을 먼저 넓히고(`preExpandSize`) 다음 틱에
  칸을 펼친다. 같은 틱에 바꾸면 넓어진 도커 양 끝이 좁은 창에 잘려 노치가 접혔다 펼쳐지는 것처럼 끊겨 보였다. 메모 모드를 닫을 때도 같은 규칙이다.
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

## To-do 칸

위젯 칸(3~6번)에 놓는 짧은 체크리스트(`NotchWidget.todo`, `NotchTodoView`, 폭 170pt). Chap 안에만 저장한다
(`TodoStore`, `~/Library/Application Support/Chap/Todos.json`, 권한·동기화 없음, 설정 Export/Import에 안 섞임).

- 줄: 다른 목록과 같은 26pt, 16pt 체크 동그라미(완료는 블루 `checkmark.circle.fill`) + 12pt 문구(`DS.notchRowName`).
  완료 항목은 보조색 + 취소선. 최대 4개(`maxItems`)라 항목 + 추가 줄이 늘 4줄 이하로, 스크롤 없이 목록 칸 높이(113pt)에 맞는다.
- 추가: 맨 아래 "＋ Add a to-do"(항목이 있으면 "＋ Add") 줄을 누르면 바로 입력. Enter로 더하고 같은 줄에서 다음
  항목을 이어 쓴다. 칸 밖 클릭(`didClickPanel`), 다른 앱, Esc, 패널 닫힘이면 쓰던 문구를 확정하고 입력을 닫는다.
  문구는 한 줄로 다듬고 200자까지(`cleanedTitle`), 빈 문구는 버린다. 4개가 차면 추가 줄을 숨기고, 완료 항목을 지우면(Clear Completed·Delete) 다시 보인다.
- 완료: 동그라미를 누르면 체크·취소선, 0.6초 뒤 완료 항목이 아래로 내려간다(`ordered`: 할 일은 넣은 순, 완료는 완료한 순).
- 수정·삭제: 문구 더블클릭으로 고치고(비우면 삭제), 우클릭에 Mark Done/Edit/Delete. 제목 우클릭 → Clear Completed.
- 제목 옆 10pt 숫자는 남은 할 일 수다(열린 노치 안의 정보일 뿐, 닫힌 노치·메뉴 막대에는 배지를 달지 않는다).
- 이전 버전은 모르는 위젯 이름을 버리므로 `todo` 칸은 그냥 빈 칸이 된다(설정은 그대로 읽힌다).

## Quick Note 저장

- 입력하면 0.5초 뒤 저장한다(`SaveDebouncer`, 직렬 큐). 다만 **커서가 풀리는 순간 기다리지 않고 바로 저장**한다
  (`isFocused`가 false가 되면 flush).
- 커서가 풀리는 경우: 노치 패널 안에서 메모 상자 밖을 누름(`didClickPanel`의 클릭 좌표가 상자 밖), 패널이 key를
  잃음(다른 앱·바탕 클릭), 메모 상자 밖 빈 곳 탭, 분리 창(`QuickNoteNSWindow`)이 key를 잃음, Esc·닫기·분리.
- 상자 오른쪽 아래 10pt 표시: 입력 중 아직 안 쓰였으면 "Editing", 저장되면 "Saved · 6:12 PM"(오늘) /
  "Saved · Oct 4, 6:12 PM"(올해) / "Saved · Oct 4, 2025, 6:12 PM"(`QuickNoteStore.savedLabel`). 빈 메모는 표시 없음.

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
- `Sources/Chap/Views/NotchWidgetViews.swift`, `Sources/Chap/MirrorCamera.swift` — 거울·메모 위젯
- `Sources/Chap/Views/NotchLauncherPanelView.swift` — 메인 패널 + 도커 실루엣 셰이프
- `Sources/Chap/Views/NotchDropViews.swift` — Drop 도커·드롭 존·배지
- `Sources/Chap/NotchLauncherController.swift` — 창 배치·표시 로직
