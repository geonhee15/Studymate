# 콘텐츠 형식

앱은 `Resources/Content/amc8/` 아래 파일만 읽는다. 코드 수정 없이 파일만 추가하면 된다.

```
Resources/Content/amc8/
├── common.md            개념서 0장 (막혔을 때 5가지 질문, 시험 정보)
├── cheatsheet.md        개념서 부록 → 치트시트 + 플래시카드
├── unitN/
│   ├── lessons.md       개념서의 "## 유닛 N" 부분 그대로 (Scripts/split_concepts.py가 생성)
│   ├── problems.json    레슨별 연습문제 (레슨마다 10개 이상)
│   ├── quiz.json        유닛 퀴즈 8개
│   ├── test.json        유닛 테스트 15개
│   └── figures/         레슨 그림: <레슨>-<섹션>.svg 또는 <레슨>-ex<번호>.svg
└── mock/
    └── setN.json        실전 모의고사 25문항 (number 1~25)
```

## 문제 JSON

```json
{
  "id": "3-2-4",                 // 연습: "<레슨>-<번호>", 퀴즈: "<유닛>-q-<번호>", 테스트: "<유닛>-t-<번호>", 모의고사: "m<세트>-<번호>"
  "lesson": "3-2",               // 이 문제가 속하거나 확인하는 레슨 (lessons.md의 ### 번호)
  "band": "11-15",               // 난이도 = AMC 번호대: "1-10" | "11-15" | "16-20" | "21-25"
  "target": 90,                  // 목표 시간(초). 생략하면 band 기본값 60/90/120/180
  "fields": ["numberTheory"],    // counting | probability | numberTheory | algebra | geometry | statistics | logic
  "question": "영어 원문 (마크다운 + $LaTeX$)",
  "questionKo": "한국어 번역",
  "figure": "<svg …>…</svg>",    // 기하 문제는 필수. 인라인 SVG 한 덩어리
  "choices": ["4", "6", "$\\frac{5}{12}$", "$16 - 4\\pi$", "12"],   // 정확히 5개, 값이 서로 달라야 함
  "choicesKo": ["…"],            // 선택지가 문장일 때만 (숫자면 생략)
  "answer": "B",
  "hints": ["1단계", "2단계", "3단계"],   // 1~3개, 갈수록 구체적으로
  "solution": "전체 해설 (한국어, 마크다운). 마지막에 **오답 짚기**: 각 오답이 어떤 실수인지",
  "fast": "더 빠른 풀이 (있으면 반드시)",
  "verify": {
    "answer": "sum(1 for n in range(1,101) if n%7!=0)",     // 정답 값을 내는 파이썬 식 (브루트포스 환영)
    "choices": ["F(1,6)", "F(5,18)", "…"],                   // 선택지가 분수/π/√처럼 숫자로 못 읽을 때 5개의 값
    "methods": ["comb(8,2)-8"],                               // 다른 접근으로 같은 값을 내는 식. 기하는 1개 이상 필수
    "note": "검증 메모"
  },
  "number": 7                    // 모의고사만: 1~25. band는 번호대와 맞아야 함
}
```

- `verify.answer`는 여러 줄 코드도 된다. 그때는 마지막에 `result = …`로 값을 둔다 (JSON 문자열 안에서 줄바꿈은 `\n`).
- 쓸 수 있는 것: `itertools`(product, permutations, combinations), `math`, `comb`, `perm`, `factorial`, `gcd`, `lcm`, `isqrt`, `pi`, `sqrt`, `F`(Fraction), `Counter`, `lru_cache`, `isprime`, `divisors`, `digits`.
- 선택지 문자열은 `$\frac{a}{b}$`, `$3\sqrt{2}$`, `$16 - 4\pi$`, `1,440`, `$45^\circ$` 정도는 스크립트가 숫자로 읽는다. 그 밖의 형태는 `verify.choices`에 값을 쓴다.
- 기하는 `verify.answer`(방법 1)와 `verify.methods[0]`(방법 2)가 **다른 접근**이어야 한다. 예: 신발끈 공식 vs 감싸는 직사각형에서 빼기, 공식 vs 좌표 브루트포스(격자점 세기, 수치 적분).

## 규칙

- 레슨당 연습문제 10개 이상: `1-10` 3개, `11-15`와 `16-20` 합쳐 4개, `21-25` 3개.
- 유닛 퀴즈 8개, 유닛 테스트 15개. 레슨들을 고루 덮고, 각 문제의 `lesson`에 어떤 레슨을 확인하는지 적는다.
- 개념서 예제와 숫자·상황이 겹치면 안 된다. 오답 선택지는 개념서 "함정"에 나온 실수에서 만든다.
- 실제 AMC 문제 본문은 절대 넣지 않는다 (저작권). 기출은 연도-번호와 링크로만.
- 영어 문장은 실제 시험처럼 간결하게. 한국어 설명은 용어를 한국어(영어)로 병기.
- 그림: `<svg viewBox="0 0 W H" width="W" height="H" xmlns="http://www.w3.org/2000/svg">`. 선과 글자는 `stroke="currentColor"`, `fill="currentColor"`로 다크 모드에서도 보이게. 강조색은 `#4F6BF0`(파랑), `#E08A1E`(주황), `#29A066`(초록), `#DB433D`(빨강)에 `fill-opacity` 0.3~0.4. 글자는 `font-size` 11~13. 폰트는 지정하지 않는다 (시스템 폰트가 적용됨). 폭은 320 이하가 보기 좋다. 모든 좌표와 글자(라벨 폭까지)는 viewBox 안에 있어야 한다. 밖으로 나가면 렌더링에서 잘리고 `verify_content.py`가 실패로 잡는다.

## 검증

```bash
python3 -I Scripts/verify_content.py            # 전부
python3 -I Scripts/verify_content.py --unit 3   # 유닛 3만
python3 -I Scripts/verify_content.py --mock     # 모의고사만
python3 -I Scripts/verify_content.py --verbose  # 계산값 전부 출력
./build/Studymate.app/Contents/MacOS/Studymate --probe content   # 앱이 실제로 읽는지 (빌드 후)
```

검증 실패가 0개일 때만 커밋한다.
