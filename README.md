# Studymate

AMC 8을 준비하면서 매일 쓰려고 만든 macOS 학습 앱입니다. 칸 아카데미처럼 유닛과 레슨을 따라가면서 개념을 읽고,
연습문제를 풀고, 틀린 건 오답노트가 간격을 두고 다시 꺼내 줍니다. 종이로 푸는 실제 기출은 트래커에 기록하고,
실전 모의고사로 40분 시간 배분을 연습합니다. 메뉴 막대 앱 [ATFM](https://github.com/geonhee15/ATFM)과 같은 방식으로
Xcode 없이 빌드합니다.

## 스크린샷

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home.png" width="300"><br><b>홈</b><br><sub>D-day · 오늘 할 것 · 유닛별 숙련도 · 막혔을 때 5가지 질문</sub></td>
    <td align="center"><img src="docs/screenshots/unit.png" width="300"><br><b>유닛</b><br><sub>레슨별 숙련도 · 유닛 퀴즈 · 유닛 테스트</sub></td>
    <td align="center"><img src="docs/screenshots/lesson.png" width="300"><br><b>레슨</b><br><sub>왜 배우나 → 기초 → 직관 → 예제(단계별) → 팁 → 함정</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/practice.png" width="300"><br><b>연습문제</b><br><sub>영어 원문 · 목표 시간 · 힌트 3단계 · 키보드 1~5 / Enter</sub></td>
    <td align="center"><img src="docs/screenshots/practice-solved.png" width="300"><br><b>채점</b><br><sub>정답 · 해설 · 더 빠른 풀이</sub></td>
    <td align="center"><img src="docs/screenshots/stuck-sheet.png" width="300"><br><b>오답노트 등록</b><br><sub>막힌 이유 · 핵심 아이디어 한 줄</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/mistakes.png" width="300"><br><b>오답노트</b><br><sub>1일 → 3일 → 7일 → 14일 간격 반복 · 분야·이유 필터</sub></td>
    <td align="center"><img src="docs/screenshots/pastpapers.png" width="300"><br><b>기출 트래커</b><br><sub>연도 × 1~25번 · AoPS Wiki 링크 · 오답노트로 보내기</sub></td>
    <td align="center"><img src="docs/screenshots/mock-exam.png" width="300"><br><b>실전 모의고사</b><br><sub>25문항 40분 · OMR 답안지</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/mock-result.png" width="300"><br><b>모의고사 결과</b><br><sub>구간별 시간 사용 · 분야별 분석 · 해설</sub></td>
    <td align="center"><img src="docs/screenshots/stats.png" width="300"><br><b>통계</b><br><sub>분야별 정답률 · 막힌 이유 · 주간 추이 · 숙련도 변화</sub></td>
    <td align="center"><img src="docs/screenshots/lesson-figure.png" width="300"><br><b>기하 레슨</b><br><sub>인라인 SVG 그림 · KaTeX 수식</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/lesson-dark.png" width="300"><br><b>다크 모드</b></td>
    <td align="center"><img src="docs/screenshots/practice-jarvis-ko.png" width="300"><br><b>JARVIS 테마 · 한국어 번역</b></td>
    <td align="center"><img src="docs/screenshots/flashcards.png" width="300"><br><b>치트시트 플래시카드</b></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/practice-geometry.png" width="300"><br><b>기하 연습문제</b><br><sub>문제마다 붙는 인라인 SVG 그림</sub></td>
    <td align="center"><img src="docs/screenshots/paper-grading.png" width="300"><br><b>종이 기출 모드</b><br><sub>40분 타이머 + 답안지 · 직접 채점 → 기출 트래커</sub></td>
    <td align="center"><img src="docs/screenshots/quiz-summary.png" width="300"><br><b>유닛 퀴즈 결과</b><br><sub>통과 기준 6/8 · 문제별 정오와 걸린 시간 · 연습장 썸네일</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/scratchpad.png" width="300"><br><b>연습장 (그리기)</b><br><sub>문제 그림을 깔고 보조선 · 펜 2단계 · 지우개 · Shift 직선</sub></td>
    <td align="center"><img src="docs/screenshots/scratchpad-text.png" width="300"><br><b>연습장 (텍스트)</b><br><sub>고정폭 글꼴로 계산 과정 적기 · 자동 계산 없음</sub></td>
    <td></td>
  </tr>
</table>

## 지금 되는 것

- **과목 탭바**: 지금은 AMC 8 하나. `Subject` enum에 case 하나를 더하면 새 과목 탭이 붙습니다.
- **홈**: 시험(2027년 1월 22일 19:30)까지 D-day, 복습 예정인 오답과 이어서 할 레슨, 유닛별 숙련도, 막혔을 때 5가지 질문, 시험 기본 정보.
- **레슨** (9개 유닛, 43개 레슨): `docs/AMC8_concepts.md`의 내용을 한 글자도 줄이지 않고 그대로 보여줍니다.
  모든 레슨이 같은 순서(왜 배우나 → 기초 설명 → 직관 예시 → 예제 풀이 → 고급 팁 → 자주 하는 실수와 함정)이고,
  예제는 한 단계씩 펼쳐 봅니다. 수식은 번들에 넣은 KaTeX로 오프라인 렌더링하고, 기하는 인라인 SVG 그림이 붙습니다.
- **연습문제**: 레슨마다 10문제(1~10번 3, 11~20번 4, 21~25번 3 비율), 유닛 퀴즈 8문제, 유닛 테스트 15문제.
  연습 430 + 퀴즈 72 + 테스트 135 + 모의고사 100 = 737문제가 전부 이 앱을 위해 새로 만든 문제이고, 모두 검증 스크립트를 통과했습니다.
  문제는 영어 원문이 기본이고 T 키로 한국어 번역을 토글합니다. 목표 시간과 경과 타이머, 힌트 3단계(연 기록이 남음),
  제출 후 정답·전체 해설·더 빠른 풀이. 키보드: 1~5 또는 A~E 선택, Enter 제출, H 힌트, Space 다음, G 찍었음, N 연습장, Esc 나가기.
  집중 모드에서는 과목 탭과 사이드바가 숨겨집니다.
- **연습장**: 종이가 없을 때 실제 시험의 연습지처럼 쓰는 패널. 연습문제·퀴즈·테스트·오답 복습·실전 모의고사 화면 오른쪽에
  접었다 펼 수 있고(N 키), 폭은 드래그로 조절하며 펼침 상태와 폭을 기억합니다. **그리기**는 트랙패드·마우스로 자유롭게 그리고,
  Sidecar의 Apple Pencil 필압이 선 굵기에 반영됩니다. 펜 굵기 2단계, 지우개, 색 3개(기본·빨강·파랑), Shift를 누르면 직선(자),
  ⌘Z / ⇧⌘Z 실행 취소·다시 실행, 전체 지우기. 문제에 그림이 있으면 "그림 가져오기"로 그 그림을 연하게 깔고 위에 보조선을
  긋습니다. 모눈은 없습니다(실제 시험에서 모눈종이 금지). **텍스트**는 고정폭 글꼴로 계산 과정을 적는 곳이고 계산기나 자동
  계산은 없습니다. 연습장에 포커스가 있는 동안은 문제 화면의 단일 키 단축키가 꺼지고(패널 테두리가 강조됨), Esc를 누르면 문제로
  돌아옵니다. 문제별·시도별로 자동 저장되어 제출 후 해설과 나란히 보고, 같은 문제를 다시 풀면 빈 연습장에서 시작하되 이전 시도는
  남습니다. 오답노트 항목과 퀴즈·테스트 결과, 모의고사 결과에서 그 시도의 연습장을 썸네일로 보고 크게 열 수 있습니다.
- **숙련도** (칸 아카데미 방식): 시도함 → 익숙함(연습 7개 이상, 최근 10개 정답률 70%) → 숙련(유닛 퀴즈 6/8 통과)
  → 마스터(유닛 테스트 12/15 통과 + 7일 뒤 재확인 통과). 기준은 앱 안 물음표 팝오버에도 적혀 있습니다.
- **오답노트**: 틀렸거나, 목표 시간을 넘겼거나, "찍었음"을 켠 문제는 막힌 이유(개념 몰랐음 / 아이디어 안 떠오름 / 계산 실수 /
  문제 잘못 읽음)와 핵심 아이디어 한 줄을 적고 자동 등록됩니다. 1일 → 3일 → 7일 → 14일 간격으로 다시 나오고, 해설 안 보고
  맞히면 다음 단계, 틀리면 1일로. 14일 단계를 통과하면 졸업. 분야·이유 필터와 "이번 주 약한 분야 Top 2".
- **기출 트래커**: 2000~2023년(2021년은 시행되지 않음) × 1~25번 그리드. 칸마다 안 풂 / 맞음 / 틀림 / 오래 걸림 / 찍어서 맞음,
  걸린 시간, 분야, 메모. 칸을 누르면 AoPS Wiki 해당 문제 페이지를 열 수 있고, 틀림·오래 걸림·찍음은 오답노트로 보냅니다.
  2024~2026년은 "실전 모의고사용으로 아껴두기" 잠금. 실제 AMC 문제 본문은 앱에 들어 있지 않습니다(연도-번호와 링크만).
- **실전 모의고사**: 앱 오리지널 25문항 세트 4개, 40분, 난이도는 번호대를 따라 올라갑니다. OMR처럼 답을 표시하고 자유롭게
  이동하며, 끝나면 채점 + 분야별 분석 + 구간별(1~10 / 11~20 / 21~25) 시간 사용 그래프(목표 10 / 15 / 15분)와 해설.
  **종이 기출 모드**는 문제 없이 40분 타이머와 답안지만 주고, 직접 정오를 체크하면 기출 트래커에 반영됩니다.
- **통계**: 분야별 정답률과 평균 시간(최근 추세 포함), 막힌 이유 분포, 최근 8주 푼 문제 수와 정답률, 숙련도 변화, 모의고사 점수 추이,
  기출 번호대별 정답률.
- **치트시트**: 개념서 부록(제곱수, 소수, 피타고라스 수, 분수-소수-퍼센트, 조합 값, 일의 자리 주기 …)을 표로, 그리고 플래시카드 모드로.
- **설정**: 외관(시스템/라이트/다크), 테마(기본 · JARVIS · 미드나이트 · 세이지), 집중 모드, 한국어 먼저 보기, 데이터 폴더, 기록 초기화.
- 사용자 데이터는 `~/Library/Application Support/Studymate/`에 JSON으로 자동 저장됩니다
  (`progress.json`, `mistakes.json`, `pastpapers.json`, `mocks.json`, 연습장은 `scratch/<문제>/<시도>.json`에 획 벡터와 텍스트).
  창 크기와 위치도 기억합니다.

## 정답 검증

정답이 틀린 문제는 없는 것보다 나쁩니다. 모든 문제는 `verify` 블록에 파이썬 식을 달고 있고
`Scripts/verify_content.py`가 브루트포스나 직접 계산으로 정답을 확인합니다. 선택지 5개의 값이 서로 다른지, 정답이 정확히
하나인지, 레슨당 문제 수와 난이도 분포, 퀴즈 8 / 테스트 15 / 모의고사 25문항과 번호대도 함께 검사합니다. 기하 문제는
서로 다른 두 방법(`verify.answer`와 `verify.methods`)이 일치해야 하고 그 과정을 로그에 남깁니다.

```bash
python3 -I Scripts/verify_content.py            # 전체
python3 -I Scripts/verify_content.py --unit 5   # 유닛 5만, --mock 은 모의고사만, --verbose 는 계산값 전부
python3 -I Scripts/verify_examples.py           # 개념서 예제 답
./build/Studymate.app/Contents/MacOS/Studymate --probe content   # 앱이 실제로 읽는 콘텐츠 검사
```

검증 실패가 0개일 때만 커밋합니다.

## 빌드

Xcode 없이 Command Line Tools만 있으면 됩니다 (macOS 14+, Swift 5.9+).

```bash
./build.sh          # build/Studymate.app 생성 + ~/Applications/Studymate.app 설치
./build.sh --run    # 빌드 후 실행
./build.sh debug    # 디버그 빌드 (설치 안 함)
```

`build.sh`는 `swiftc`로 직접 컴파일한 뒤 `.app` 번들을 조립하고 서명합니다. 키체인에 코드 서명 인증서가 있으면
(`STUDYMATE_SIGN_IDENTITY`, 기본값 `Omni Dev Signing`) 그걸로, 없으면 ad-hoc으로 서명합니다. 릴리즈 빌드는 `~/Applications`에
설치하고(`STUDYMATE_INSTALL_DIR`로 변경), `build/Studymate.app`은 스냅샷 등 개발용입니다. 일부 Command Line Tools 설치에서
옛 `module.modulemap`이 남아 `SwiftBridging` 재정의 오류가 나면 `Scripts/toolchain-fix`의 VFS 오버레이가 자동으로 적용됩니다.
첫 빌드는 모듈 캐시를 만드느라 몇 분 걸리고, 그 뒤로는 수십 초면 끝납니다.

개발용 환경 변수:

| 변수 | 동작 |
|---|---|
| `STUDYMATE_TAB=lesson:1-1` | 시작 화면. `home` · `unit:1` · `lesson:1-1` · `practice:1-1` · `quiz:1` · `test:1` · `mistakes` · `review`(오답 복습 세션) · `pastpapers` · `mock` · `mock:1` · `paper:2019` · `stats` · `cheatsheet` · `settings` |
| `STUDYMATE_SNAPSHOT=/path/out.png` | 잠시 뒤 창을 PNG로 저장 (화면 기록 권한 불필요). `STUDYMATE_SNAPSHOT_DELAY=3`, `STUDYMATE_SNAPSHOT_QUIT=1`(저장 후 종료), `STUDYMATE_SNAPSHOT_SCREEN=1`(시트·팝오버 포함) |
| `STUDYMATE_WINDOW=1180x760` | 이번 실행의 창 크기 (저장 안 함) |
| `STUDYMATE_DEBUG_DATA_DIR=<dir>` | 모든 저장소를 지정 폴더에서 읽고 씀 (`Scripts/dev-run.sh`, `Scripts/screenshots.sh`가 사용) |
| `STUDYMATE_DEBUG_SAMPLE=1` | 위 폴더에 스크린샷용 샘플 기록을 채움 |
| `STUDYMATE_DEBUG_PROBLEM="select:C,hint:2"` | 문제 화면을 조작: `select:C` · `hint:N` · `guess` · `submit:B` · `next` · `stuck`. 모의고사: `answer:B` · `go:12` · `fill:C` · `finish`. 종이 기출: `fill:C` · `grade` · `mark` |
| `STUDYMATE_DEBUG_LANG=ko` | 문제 화면을 한국어로 시작 |
| `STUDYMATE_DEBUG_THEME=jarvis` · `STUDYMATE_DEBUG_APPEARANCE=dark` | 이번 실행만 테마·외관 지정 |
| `STUDYMATE_DEBUG_FLASHCARDS=1` | 치트시트를 플래시카드 모드로 |
| `STUDYMATE_DEBUG_SCROLL=examples` | 레슨 화면을 해당 섹션으로 스크롤 (`why` · `basics` · `intuition` · `examples` · `tips` · `pitfalls`) |
| `STUDYMATE_DEBUG_SCRATCH=open,sample,figure` | 연습장을 펼친 채 시작. `sample`(샘플 획과 텍스트) · `figure`(문제 그림 깔기) · `text`(텍스트 모드) · `viewer`(첫 썸네일의 연습장 크게 보기 열기) · `pane`(모의고사 결과의 내 연습장 창 열기) |
| `STUDYMATE_DEBUG_KEYS="n,focus,c,esc,c,cmd+z"` | 키 입력을 순서대로 보내고 단계마다 상태를 로그에 남김 (단축키 격리 확인용). `focus` · `draw` · `line` · `erase` · `stress` 단계는 연습장을 직접 조작 |
| `STUDYMATE_CONTENT_DIR=<dir>` · `STUDYMATE_WEB_DIR=<dir>` | 번들 대신 지정 폴더의 콘텐츠 / 웹 리소스 사용 |

`Scripts/dev-run.sh lesson:1-1`처럼 화면 이름을 주면 위 조합으로 실행하고 `build/snap-<화면>.png`를 남깁니다
(기록은 `build/devdata`에 쓰므로 실제 학습 데이터는 건드리지 않습니다).
`Scripts/screenshots.sh`는 README 스크린샷 전부를 샘플 데이터로 다시 만듭니다.

## 구조

```
Sources/Studymate
├── App/        진입점, 창(NSVisualEffectView + NSHostingView), 메뉴, 디버그 환경변수, --probe, 샘플 데이터
├── Support/    테마(Theme · AppTheme · ThemeManager), 데이터 폴더와 JSON 파일, 포맷터, 시험 정보
├── Content/    모델(Unit · Lesson · Problem · MockSet), 레슨 마크다운 파서, 마크다운 → HTML, 콘텐츠 로더
├── Web/        WKWebView 브리지(MathWebView · WebBridge), HTML 템플릿(레슨 · 문제 · 문서)
├── Progress/   학습 기록(ProgressStore), 숙련도(MasteryEngine), 오답노트(MistakeStore), 기출(PastPaperStore), 모의고사(MockStore)
├── Scratch/    연습장: 획·패드 모델, 저장소(ScratchStore), 그리기 캔버스(비트맵 캐시 + 필압), 텍스트 모드, 패널·썸네일·크게 보기
└── UI/         화면 전부 (홈 · 유닛 · 레슨 · 문제 풀이 · 오답노트 · 기출 트래커 · 모의고사 · 통계 · 치트시트 · 설정)
Resources/
├── KaTeX/      KaTeX 0.16 (JS · CSS · woff2 폰트) — 오프라인
├── web/        웹뷰 스타일(시스템 폰트·시스템 색·다크 모드)과 브리지 스크립트
└── Content/amc8/
    ├── common.md, cheatsheet.md
    ├── unitN/  lessons.md · problems.json · quiz.json · test.json · figures/*.svg
    └── mock/   set1.json … set4.json
docs/AMC8_concepts.md   콘텐츠 원본 (개념서). Scripts/split_concepts.py가 unitN/lessons.md로 나눔
Scripts/                build 보조, 스냅샷, 검증 스크립트
```

## 콘텐츠 추가하는 법

코드를 고치지 않고 `Resources/Content/amc8/` 아래 파일만 더하면 됩니다. 형식과 규칙은
[docs/CONTENT_FORMAT.md](docs/CONTENT_FORMAT.md)에 있습니다.

1. 개념 설명은 `docs/AMC8_concepts.md`를 고치고 `python3 Scripts/split_concepts.py`로 유닛별 `lessons.md`를 다시 만듭니다.
   `## 유닛 N.`과 `### N-M.` 번호가 앱의 유닛·레슨 구조가 됩니다.
2. 문제는 `unitN/problems.json`(레슨별 연습), `quiz.json`, `test.json`, `mock/setN.json`에 JSON으로 추가합니다.
   영어 원문 + 한국어 번역, 선택지 5개, 힌트 1~3개, 해설, 그리고 정답을 계산하는 `verify` 식.
3. 그림은 인라인 SVG. 레슨 그림은 `unitN/figures/<레슨>-<섹션>.svg` 또는 `<레슨>-ex<N>.svg`.
4. `python3 -I Scripts/verify_content.py`가 0 failures인지 확인하고, 빌드 후 `--probe content`로 앱이 읽는지 봅니다.

## 참고

- 실제 AMC 문제 본문은 저작권 때문에 앱에도 이 저장소에도 넣지 않습니다. 기출은 연도-번호와 AoPS Wiki 링크로만 다룹니다.
- 2021년 AMC 8은 시행되지 않았습니다 (MAA가 2022년부터 1월 시행으로 옮김).
- KaTeX는 MIT 라이선스입니다 (`Resources/KaTeX/LICENSE`).
