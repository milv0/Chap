# Notch Surface Geometry Spec

노치 표면(메인 패널·Chap Drop 도커·Drop 배지)의 시각 스펙.
**모든 수치의 단일 출처는 `Sources/ChapCore/NotchGeometry.swift`** 이며,
이 문서는 각 수치가 화면 어디에 해당하는지 보여주는 지도다.

스펙을 조정하고 싶을 때: 아래 이름으로 값을 지정하거나("badgeNotchOverlap을
8로"), 스크린샷에 마킹해서 전달하면 된다.

## 배치 다이어그램

```
 화면 최상단 ────────────────────────────────────────────────────────
 │  menu bar   ╭[■ badge]▓▓[═══════ notch (hardware) ═══════]      │
 │             │ 32×(32+12)         185 × 32 (runtime)             │
 └─────────────┴──────────────────────────────────────────────────┘
                ↑ badgeCornerRadius 10 (좌측 상·하)
                ↑ badgeNotchOverlap 12 (노치 밑으로 파고듦 ▓)

 도커가 펼쳐지면 (노치 중앙 정렬):
              ╭──flare 10                        flare 10──╮
              │   [badge span 32][═ notch 185 ═][future 32] │
              │                                             │
              ╰──r 18 (drop) / r 20 (panel)              ───╯
                        └── iceberg: 톱니 깊이 46, 폭 68 ──┘
```

## 수치 표

| 이름 | 값 | 의미 |
|---|---|---|
| `badgeNotchOverlap` | 12 | 배지가 노치 밑으로 파고드는 겹침. 노치의 둥근 모서리를 검정으로 채움 |
| `badgeCornerRadius` | 10 | 배지 왼쪽 상·하 모서리. 노치 라운드와 동일하게 유지 |
| `dockFlareRadius` | 10 | 도커 상단 오목 플레어. 상단바에서 흘러나오는 곡선. **폭 보정 계산과 공유** |
| `dropDockBottomRadius` | 18 | Drop 도커(드롭 존·리스트) 하단 라운드 |
| `panelBottomRadius` | 20 | 메인 런처 패널 하단 라운드 |
| `dropZoneContentHeight` | 64 | 드롭 존 콘텐츠 높이 |
| `icebergJagDepth` | 46 | Iceberg 스타일 톱니 최대 깊이 |
| `icebergToothWidth` | 68 | Iceberg 톱니 하나의 목표 폭 |
| `shadowPadding` | 28 | 그림자 클리핑 방지 투명 여백 |

## 런타임 파생 값 (하드코딩 아님)

기종·디스플레이 스케일에 따라 달라지므로 화면 API에서 매번 계산한다.

| 값 | 계산 | 14" MBP 기본 스케일 기준 |
|---|---|---|
| 노치 높이 | `safeAreaInsets.top` | 32pt |
| 노치 폭 | `auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX` (nil이면 200 폴백) | 185pt |
| 배지 한 변 | 노치 높이 | 32pt |
| Drop 도커 검정 폭 | 노치 폭 + 배지 한 변 × 2 + 플레어 × 2 | 269pt |

## 관련 파일

- `Sources/ChapCore/NotchGeometry.swift` — 수치의 단일 출처
- `Sources/ChapCore/NotchLauncherPolicy.swift` — 표시 조건·프레임 계산 (테스트로 고정)
- `Sources/Chap/Views/NotchLauncherPanelView.swift` — 메인 패널 + 도커 실루엣 셰이프
- `Sources/Chap/Views/NotchDropViews.swift` — Drop 도커·드롭 존·배지
- `Sources/Chap/NotchLauncherController.swift` — 창 배치·표시 로직
