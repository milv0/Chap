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
                        └── iceberg: 톱니 깊이 46, 폭 68 ──┘
```

## 좌우 배지

- **오른쪽 Drop 배지**: 보관함에 파일이 있을 때 표시. hover로 파일 도커,
  드래그로 드롭 존, 직접 드롭 가능.
- **왼쪽 Awake 배지**: Keep Awake 세션이 활성일 때 커피 아이콘 표시.
  순수 인디케이터로 마우스를 받지 않는다. Drop 배지와 같은 크기의 미러.
  메인 도커가 열리면 왼쪽으로 슬라이딩 확장(`badgeExpandedBodyWidth` 86)되어
  아이콘은 왼쪽, 오른쪽에 h:mm 남은 시간이 붙는다.

## 실루엣 문법: 오목 플레어

모든 노치 표면(메인 패널·Drop 도커·드롭 존·배지)의 **상단 모서리는 볼록
라운드가 아니라 오목 플레어**다. `NotchDockShape`의 상단은 상단바 라인에서
바깥으로 흐르는 오목 곡선(반경 `dockFlareRadius`)으로 시작해 본체 벽으로
이어진다 — 실제 노치가 메뉴바와 만나는 방식과 같은 문법이라 표면이
"상단바에서 빠져나온" 것처럼 보인다.

이 구조의 부작용 두 가지를 항상 기억할 것:

1. **벽 인셋** — 본체 벽은 프레임보다 좌우 각 `dockFlareRadius`만큼
   안쪽에 선다. 눈에 보이는 검정 폭을 맞추려면 프레임 폭에 플레어 × 2를
   보정해야 한다 (`dropDockContentWidth`가 하는 일).
2. **림 스트로크** — 림 하이라이트는 상단 변을 긋지 않는 `isRim` 경로를
   써야 노치 경계에 흰 줄이 생기지 않는다.

배지도 같은 `NotchDockShape`을 쓴다: 상단 오목 플레어 + 하단 볼록
(`badgeCornerRadius`). 노치 쪽 절반은 겹침(overlap)으로 하드웨어 밑에
숨고 바깥 프로필만 보인다.

## 수치 표

| 이름 | 값 | 의미 |
|---|---|---|
| `badgeExpandedBodyWidth` | 86 | 메인 도커가 열렸을 때 Awake 배지의 확장 본체 폭 |
| `badgeBodyWidth` | 34 | 배지 본체(보이는 검정) 폭. 높이는 노치 높이 |
| `badgeNotchOverlap` | 12 | 배지가 노치 밑으로 파고드는 겹침 (우측 배지 → 노치의 둥근 오른쪽 아래 모서리를 채움) |
| `badgeCornerRadius` | 6 | 배지 하단 볼록 모서리 (하드웨어 노치 곡률에 근접). 상단은 `dockFlareRadius` 오목 플레어 |
| `dockFlareRadius` | 10 | 도커 상단 오목 플레어. 상단바에서 흘러나오는 곡선. **폭 보정 계산과 공유** |
| `dockBottomRadius` | 18 | 모든 도커(메인 패널·드롭 존·리스트) 하단 라운드. 배지만 비례상 작은 `badgeCornerRadius` |
| `dropZoneContentHeight` | 64 | 드롭 존 콘텐츠 높이 |
| `icebergJagDepth` | 46 | Iceberg 스타일 톱니 최대 깊이 |
| `icebergToothWidth` | 68 | Iceberg 톱니 하나의 목표 폭 |
| `stripBadgeClearance` | 10 | 배지 코너 뒤 평평한 여유. 영역 구분 + 정보 자리 |
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

## 모션 기준

모든 노치 표면이 같은 타이밍 기준을 쓴다. 닫힘 관련 값은 전부
`closeDuration` 하나에서 파생된다.

| 이름 | 값 | 의미 |
|---|---|---|
| `openAnimation` | spring 440/30 (~0.3s) | 패널 펼침. 노치 상단 기준 스프링 확장 |
| `closeDuration` | 0.18s | 모든 도커 공통 닫힘 시간. 메인 패널은 접힘, Drop 도커는 페이드 |
| 창 제거 | closeDuration + 0.02s | 닫힘 애니메이션 종료 직후 |
| `hideDelay` | 0.2s | 마우스가 영역 밖에 머물면 닫힘 판정 |
| `hoverMargin` | 10 | 노치·배지의 hover/드래그 인식 범위를 시각 경계보다 넓히는 여유 |
| `pollInterval` | 0.08s | 마우스 위치 폴링 주기 |

## 관련 파일

- `Sources/ChapCore/NotchGeometry.swift` — 수치의 단일 출처
- `Sources/ChapCore/NotchLauncherPolicy.swift` — 표시 조건·프레임 계산 (테스트로 고정)
- `Sources/Chap/Views/NotchLauncherPanelView.swift` — 메인 패널 + 도커 실루엣 셰이프
- `Sources/Chap/Views/NotchDropViews.swift` — Drop 도커·드롭 존·배지
- `Sources/Chap/NotchLauncherController.swift` — 창 배치·표시 로직
