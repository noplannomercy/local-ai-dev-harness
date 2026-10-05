# 2026 Local AI Coding Environment 재조사 — Claude(Fable) 독립 조사 결과

- 조사일: 2026-10-04
- 지시서: `docs/research.md` (본문 + GPT 교차검토 보충 + 3-way 시나리오 Addendum)
- 성격: GPT와 **독립적으로** 수행한 조사. GPT 결과는 보지 않았다. 대조는 이 문서 이후 단계다.
- 하지 않은 것: 설치, 구현, benchmark, PoC, 제품 선정. 전부 문헌·공식문서·저장소 조사다.

---

## 결론 (조사 종료 시점, 2026-10-04)

본문과 Addendum, GPT 교차검토를 거쳐 닫은 결론이다. 근거는 Addendum A1~A3에 있다.

### 결정한 것

1. **첫 질문이 바뀐다.** "폐쇄망 안에서 AI 개발환경을 어떻게 만들까"가 아니라 "개발자 AI 트래픽까지 완전 폐쇄해야 하는 실제 요구사항이 무엇이고, 그 출처가 법·인증·계약·사내정책 중 어디인가"가 먼저다.
2. **현재 조사 범위에서는 유통사가 금융권보다 더 닫혀 있어야 할 근거가 보이지 않는다.** 금융 망분리 규정은 유통사에 적용되지 않고, 유통사에 걸리는 개인정보 안전성 확보조치 기준은 2025-10 개정으로 위험분석 기반으로 완화됐다. 금융사(KB증권, 카카오뱅크)는 통제 게이트웨이를 두고 클라우드 프런티어 모델을 개발 단말에 이미 열었다.
3. **A/B/C는 동등 후보가 아니다. B가 주안이다.** 개발 PC의 정상적인 agent → 고객 통제 게이트웨이·사설 연결 → 승인된 리전 내 클라우드 모델. 인증, 로그, 모델 허용 목록, 리전 고정은 게이트웨이에 둔다.
4. **C는 fallback이다.** 고객이 외부 리전 전송을 실제로 전면 금지할 때만 쓴다. 실물 후보는 오픈웨이트 모델 + 모델 비종속 agent다. GDC Gemini는 협의 카드로만 기록한다.
5. **실물 단계에서 만드는 것은 B의 원형이다.** 강한 모델과 정상 agent로 FE+BE 개발 흐름의 기준선을 먼저 만들고, 그것을 게이트웨이 뒤로 넣을 때 무엇이 보존되는지를 본다.

### 이 결론에 붙는 단서

- **법률 판단이 아니다.** 규제 부분은 보도와 규제기관 공지 요약에 근거했고 고시 원문 조문을 대조하지 않았다. 고객에게 제시하기 전에 법무·보안 담당의 확인이 필요하다.
- **조사하지 않은 구속 요인이 있다.** 아래는 이번 조사에서 확인하지 않았고, 해당하면 결론 2의 범위가 줄어든다.
  - ISMS-P 인증 의무와 그 통제 항목(특히 개인정보처리시스템 관련 단말의 망 분리 요구).
  - 그룹 내 금융성 사업(자체 카드, 선불·간편결제 등)이 있을 경우 해당 시스템에 걸리는 전자금융·신용정보 규제.
  - 카드 데이터 관련 계약상 의무, 그룹 공통 보안 정책, 과거 사고에 따른 내부 통제.
- **따라서 "개발 단말 전체 폐쇄는 사내 정책일 가능성이 높다"는 가설이다.** 고객사에 물어서 확인할 항목이지 주장할 항목이 아니다. 시스템별로 답이 다를 수 있다(일반 업무 시스템과 결제·개인정보 시스템).
- **KB증권 선례의 근거 수준**: 금융보안원 "적합" 판정은 공식 보도자료 기반 기사로 확인했다. Claude Code·Bedrock·게이트웨이 구조는 AWS 행사 발표에 근거한다.

---

## 0. 읽기 전에

### 0.1 조사 방법

5개 갈래(기본 능력 / 방법론 팩 / code intelligence / 신규 접근·실증 근거 / 환경·배포)로 나눠 병렬 조사했다. 공식 문서와 GitHub 저장소(`gh api`)를 우선했고, 논문은 초록 중심으로 확인했다.

### 0.2 근거 수준 표기

| 표기 | 의미 |
|---|---|
| **[재확인]** | 조사 결과를 받은 뒤 메인 세션에서 원문/저장소를 다시 열어 확인한 항목 |
| (표기 없음) | 조사 갈래에서 1차 출처를 열어 확인했다고 보고한 항목. 재확인은 하지 않았다 |
| **[2차]** | 검색 요약이나 2차 자료로만 확인한 항목. 그대로 믿으면 안 된다 |
| **[저자 측정]** | 도구 저자나 벤더가 스스로 측정한 수치. 독립 재현 없음 |

### 0.3 이해당사자 고지

이 조사를 수행한 것은 Claude Code 위의 Claude 모델이고, 조사 세션에 Superpowers와 gstack이 설치되어 있다. Claude Code 및 그 생태계에 대한 평가는 편향 가능성이 있다. 대응으로 각 갈래에 부정적 증거를 의도적으로 찾도록 지시했지만, 그것으로 편향이 제거됐다고 볼 수는 없다. **Claude Code 관련 판단은 GPT 결과와 대조할 때 우선 의심 대상이다.**

### 0.4 문헌 조사의 한계

"실제 생산성이 오르는가"는 이번 조사로 답할 수 없다. 확인할 수 있는 것은 현재 무엇을 제공하는가, 무엇이 겹치는가, 어떤 전제에서 동작하는가, 배포할 수 있는가까지다. 그 너머는 `추가 검증 필요`로 남겼다.

---

## 1. 핵심 요약

1. **과거 후보는 전부 살아 있다.** gstack, Superpowers, Serena, CodeGraph 계열, Graphify 모두 2026-09~10에 릴리스나 커밋이 있다. 다만 "살아 있음"과 "추가 가치가 있음"은 별개이고, 후자를 독립적으로 입증한 자료는 어느 것도 없다.
2. **방법론 팩 저자들이 스스로 프롬프트를 줄이고 있다.** gstack과 Superpowers 모두 최근 릴리스에서 "강한 모델이 과하게 적용하는 강제 문구"를 걷어냈다. 과거 scaffolding이 새 모델에서 오작동한다는 저자 본인의 인정이다.
3. **계획·서브에이전트·코드리뷰·컴팩션·메모리·hooks·skills·plugins·조직 정책은 주요 agent 5종에 모두 내장됐다.** 반대로 TDD 등 프로세스 강제, 요구사항 추적, 팀 표준의 "내용"은 내장되지 않았다. 그릇은 제공되고 내용은 조직이 채워야 한다.
4. **Code intelligence는 "토큰과 호출 수를 줄인다"는 근거는 있으나 "정답률을 올린다"는 독립 근거는 찾지 못했다.** 한 연구에서는 그래프 방식이 토큰을 10배 줄였지만 품질은 파일 탐색보다 낮았다(83% 대 92%, 저자 측정).
5. **하네스 효과는 실재하지만 방향이 일정하지 않다.** 같은 모델이 하네스에 따라 점수가 달라지고, 모델 순위가 하네스에 따라 뒤집히는 결과도 있다. "얇을수록 좋다"도 "두꺼울수록 좋다"도 일반 법칙으로 확립되지 않았다.
6. **"약한 모델일수록 scaffolding이 필요하다"는 가설은 부분적으로만 지지된다.** 약한 모델이 하네스에 더 민감하다는 신호는 있지만, 프런티어 모델용으로 설계된 복잡한 하네스를 그대로 얹어서 통한다는 증거는 없다. 코딩 실무에서의 직접 증거는 찾지 못했다.
7. **환경 B(enterprise managed)에서는 로컬 agent 루프가 거의 그대로 유지된다.** 잃는 것은 주로 벤더 호스팅 기능(웹 검색, 클라우드 agent, 호스팅 코드리뷰, 서버 기반 중앙관리)이다. AWS 서울 리전에서 Claude Opus 5 / Sonnet 5의 리전 내 추론이 2026-09-29부터 제공된다 **[재확인]**.
8. **환경 C(완전 격리)에서는 agent 선택지가 바뀐다.** Claude Code는 비-Claude 모델 라우팅을 공식 지원하지 않는다 **[재확인]**. Cursor는 자체 백엔드가 필수다. C에서 문서상 지원되는 것은 OpenCode, Cline, Copilot CLI(오프라인 모드), Codex CLI(조건부) 등이다.
9. **B와 C가 미확정이면 "두 환경에 같은 설정 구조로 걸치는 agent"가 따로 의미를 가진다.** OpenCode와 Codex CLI는 provider 블록 교체로 B↔C 전환이 문서화되어 있다. Claude Code를 B의 표준으로 잡으면 C로 떨어질 때 agent 자체를 바꿔야 한다.
10. **배포의 실제 걸림돌은 도구 기능보다 Windows 주변 조건이다.** WSL2 허용 여부, 서명되지 않은 바이너리, 최초 실행 시 외부 다운로드, 자동 업데이트 방식이 후보별 탈락 사유가 될 수 있다.

---

## 2. 관찰된 생태계 구조

조사 후 자연스럽게 나뉜 층은 다음과 같다. 사전에 고정한 분류가 아니라 결과에서 나온 것이다.

| 층 | 내용 | 2026년 상태 |
|---|---|---|
| 모델 | 프런티어 closed 모델 / 오픈웨이트 모델 | 환경 A·B와 C를 가르는 축 |
| Agent (= 기본 하네스) | Claude Code, Codex, Copilot, Cursor, Gemini CLI, OpenCode, Cline 등 | 과거 외부 하네스 기능 상당 부분을 흡수 |
| 확장 그릇 | 지침 파일(AGENTS.md 등), skills, hooks, plugins, MCP, 조직 정책 | 5개 주요 agent 모두 제공. skills와 AGENTS.md는 사실상 공통 포맷 |
| 방법론 팩 | gstack, Superpowers, Spec Kit, BMAD 등 | 그릇 위에 얹는 "내용". 저자들이 축소 중 |
| Code intelligence | LSP 계열, 그래프 계열, 임베딩 계열 | agent 내장 LSP와 겹치기 시작 |
| 배포·정책 | 설치, 업데이트, managed settings, 사설 마켓플레이스 | 벤더별로 형식이 다르고 호환되지 않음 |

---

## 3. 과거 후보의 현재 상태 (질문 1)

| 후보 | 상태 | 무엇이 변했나 | 지금 해결하는 문제 |
|---|---|---|---|
| **gstack** | 활발. v1.91.18.0, MIT, 릴리스 태그 없이 `main`에 하루 여러 번 반영 **[재확인]** | 약 60개 skill 디렉터리, Bun 바이너리, headless Chromium daemon으로 커짐. 2026-10-03 릴리스에서 강제 문구를 강한 모델용으로 완화 | 브라우저 QA 루프, 교차 벤더 리뷰, 창업자 관점 제품 검토, 릴리스 파이프라인 |
| **Superpowers** | 활발. v6.4.2 (2026-09-25), MIT, 태그 릴리스 **[재확인]** | 15개 markdown skill로 유지. 지원 agent가 15종 안팎으로 확대. v6.3 "ceremony가 과제 크기에 비례", v6.4.2에서 강한 모델 대응 수정 | 강제 순서(brainstorm → spec → plan → TDD → review → verify)라는 프로세스 규율 |
| **Serena** | 활발. v1.7.0 (2026-08-09) **[재확인]** | **라이선스가 MIT에서 GPL-3.0-or-later로 변경**(본체. SolidLSP만 MIT, 결합 배포물은 GPL) **[재확인]** | LSP 기반 심볼 탐색·참조·rename·심볼 단위 편집 |
| **CodeGraph 계열** | 이름이 여러 프로젝트에 쓰임. 가장 활발한 것은 `colbymchenry/codegraph` v1.6.2 (2026-10-03), MIT **[재확인]** | tree-sitter + SQLite 로컬 인덱스, 임베딩 불필요, 번들 바이너리 | 호출 관계 등 구조 질의의 토큰 절감 |
| **Graphify** | 활발. `Graphify-Labs/graphify` v0.9.75 (2026-10-04), Apache-2.0 **[재확인]** | 코드는 tree-sitter로 로컬 처리, 문서·이미지는 모델 API로 의미 추출 | 저장소 구조 요약과 시각화 |

각 후보의 중복·고유 가치와 배포 제약은 4~6장과 9장에서 다룬다.

---

## 4. 최신 agent와 겹치는 부분 (질문 2)

### 4.1 agent 자체에 흡수된 것

Claude Code, Codex, Gemini CLI, GitHub Copilot, Cursor 5종의 공식 문서 기준이다. "문서에 있음"은 "잘 동작함"의 증거가 아니다.

| 과거 외부 하네스가 하던 일 | 현재 |
|---|---|
| 계획 워크플로 | 5종 모두 plan 모드 내장 |
| 서브에이전트 | 5종 모두 탐색용 서브에이전트와 커스텀 agent 파일. 병렬은 Gemini CLI만 미지원 |
| 코드 리뷰 | Claude `/code-review`, Codex `/review`, Copilot code review, Cursor Bugbot. Gemini CLI는 전용 기능 미확인 |
| 컨텍스트 압축, 장기 세션 | 5종 모두 자동 압축 |
| 메모리 | Claude, Codex(기본 off), Copilot, Gemini에 있음 |
| repo map / 벡터 RAG | 대체로 agentic grep과 탐색 서브에이전트로 대체. 시맨틱 인덱스를 유지하는 것은 Copilot(VS Code) 정도 |
| 가드레일, 패키징 | hooks, skills, plugins, 마켓플레이스가 5종 모두에 있음 |
| 조직 정책 배포 | 5종 모두 관리자 강제 계층 보유 |

### 4.2 흡수되지 않은 것

- **프로세스 강제**: "테스트 먼저" 같은 규율을 강제하는 내장 모드는 어느 제품 문서에서도 찾지 못했다. hooks와 skills로 직접 구성해야 한다.
- **요구사항 → 구현 → 검증 추적, 산출물 표준**: 내장 기능이 없다.
- **팀 표준의 내용**: 지침 파일, 리뷰 기준, 권한 allowlist는 그릇만 있고 내용은 조직이 써야 한다.
- **벤더 간 호환**: hook 이벤트, plugin 포맷, 정책 파일이 제품마다 다르다.
- **Windows 네이티브 격리**: Claude Code는 네이티브 Windows에서 샌드박스 미지원, Cursor는 WSL2 경유 **[2차]**, Copilot은 실험적, Gemini는 opt-in이다. Codex만 네이티브 샌드박스를 권장 경로로 두지만 실패 이슈가 반복된다.

### 4.3 gstack — 중복과 고유

- **중복**: plan review, `/review`, `/investigate`, `/learn`, `/careful`·`/freeze`, `/ship`, 서브에이전트 fan-out은 Claude Code 기본 기능과 겹친다.
- **고유**: headless 브라우저 daemon 기반 QA 루프, Claude ↔ Codex 교차 리뷰, 창업자 관점 제품 검토, 디자인 생성, 릴리스 파이프라인.
- **성격**: 고유 부분의 상당수가 스타트업 웹 제품에 맞춰져 있다. 기존 시스템 유지보수 업무와 맞는지는 별도 판단이 필요하다.
- **비용 [저자 측정]**: 세션마다 약 6.9K 토큰의 상시 카탈로그, `/review` 호출당 약 13K 토큰.
- **독립 평가**: 한 달 사용 리뷰 1건(무기명)이 "35개 중 6개만 남기고 나머지는 제거하거나 무시"라고 보고했다. 측정치는 없다.
- **생산성 효과**: 추가 검증 필요.

### 4.4 Superpowers — 중복과 고유

- **중복**: plan 모드, 서브에이전트, worktree, 코드 리뷰, task 목록, skills 메커니즘 자체.
- **고유**: 순서 강제와 지름길 차단이라는 프로세스 규율. 도구가 아니라 절차다.
- **동작 방식**: 세션 시작 hook이 "1%라도 해당하면 반드시 skill을 호출하라"는 문구를 주입한다. 사용자 지침이 우선한다고 명시되어 있다.
- **독립 측정 (소표본)**:
  - 이슈 #2017의 사용자 실험(4과제 × 5회): 정확도는 양쪽 20/20으로 같았고, "검증된 재현 테스트"는 8/20 대 2/20, 비용은 $0.316 대 $0.176이었다.
  - 블로그 1건(n=12): 단순 과제에서는 토큰이 늘고 복잡한 과제에서는 줄었다.
- **부정적 보고**: "작은 기능에 한 시간", 단순 계획이 5시간 예산을 소진, 한 작업이 약 4시간·1.2억 토큰을 쓴 사례 등 과잉 절차 이슈가 여럿 열려 있다.
- **저자 주장 [저자 측정]**: "Superpowers 없이 만들면 더 빠르고 싸지만 버그가 훨씬 많다". 표본과 방법은 공개되지 않았다.
- **정리**: 규율 효과는 있을 법하지만 세션당 비용이 늘고, 손익은 모델과 과제에 달려 있다. 추가 검증 필요.

---

## 5. Code intelligence는 지금도 필요한가

### 5.1 도구별 사실

| 도구 | 방식 | 언어·형식 의존성 | 로컬/오프라인 | 주의점 |
|---|---|---|---|---|
| **Serena** | 언어 서버(LSP) | 40여 개 언어. 언어마다 언어 서버 필요. 문서에 SQL, JSP, XML 매퍼 항목 없음 | 임베딩·외부 API 불필요. uv + Python 3.13 | GPL 전환. Java는 최초 실행 시 약 500MB 외부 다운로드(이슈 #1414). Windows 열린 이슈 19건 |
| **colbymchenry/codegraph** | tree-sitter + SQLite | 30여 개 언어, 17개 프레임워크 라우팅 인식. 동적 디스패치·리플렉션·런타임 DI는 해소 못 함 | 100% 로컬, 번들 바이너리 | "모델이 도구를 호출하지 않는다"는 이슈 2건이 열려 있음 |
| **codebase-memory-mcp** | tree-sitter + 내장 임베딩 | 162개 언어 파싱 | 단일 정적 바이너리, 외부 API 불필요 | README가 Windows Defender 오탐을 직접 언급 |
| **Graphify** | tree-sitter(코드) + 모델 API(문서) | 37개 언어 | Python 3.10+. `--code-only`로 모델 호출 제외 가능 | 약 5000 노드 초과 시 시각화가 어려움. Windows 이슈 다수 |
| **Agent 내장 LSP** | Claude Code LSP 도구, OpenCode LSP | Claude Code 공식 플러그인 13개 언어. 언어 서버 바이너리는 직접 설치 | 로컬 | 읽기 전용. 메모리 증가와 진단 오탐이 문서에 명시됨 |
| **ast-grep** | 구조 검색·치환 CLI | tree-sitter 문법 기반 | Rust 단일 바이너리, 인덱스 없음 | MCP가 아니라 CLI |
| **벡터 RAG MCP** (claude-context 등) | 임베딩 | — | 기본 구성이 외부 임베딩 API와 클라우드 벡터 DB를 요구 | 환경 C에 그대로 쓸 수 없음 |

어느 도구든 **정적 분석 밖의 연결**(리플렉션, DI, 매퍼 파일, 독자 UI 포맷, 혼합 언어 교차 참조)은 스스로 한계를 밝히거나 지원 목록에 없다. 실제 스택이 확인되면 이 열에 대입해 판단한다.

### 5.2 agentic search 대 code intelligence 증거

**비교적 확립된 것**

- Anthropic과 Cline은 인덱싱 대신 agentic search를 택했다고 공개적으로 밝혔다. 이유는 단순성, 신선도, 보안이다. 벤더 진술이고 수치는 없다. Cursor도 임베딩 인덱스를 줄이고 grep 쪽으로 옮기는 중이라는 스태프 발언이 있다.
- SWE-Explore(arXiv 2606.07297): agentic 탐색이 BM25·dense 검색을 크게 앞섰다. 다만 일반 agent의 라인 수준 재현율은 낮았고(0.15~0.19), 코드 그래프를 반복 탐색하는 특화 로컬라이저가 훨씬 높았다(0.788, 지표 정의 재확인 필요).

**논쟁 중인 것**

- Codebase-Memory 논문(arXiv 2603.27277, 도구 저자 작성): 그래프 agent가 토큰을 10배 줄였지만 품질은 83% 대 92%로 파일 탐색보다 낮았다. 구조 질의에서는 동등 이상, 전체 소스 맥락이 필요한 질의에서는 파일 탐색이 우세했다.
- Cursor(벤더): 시맨틱 검색 추가 시 오프라인 평가 +12.5%, 실사용 코드 유지율은 전체 +0.3%, 1000개 이상 파일 저장소 +2.6%.
- Serena 자체 평가: 저자도 "작은 편집은 내장 도구가 더 가볍다", "가장 큰 가치는 파일 간 리팩터링"이라고 인정한다.
- 경쟁 도구 저자의 벤치(단일 Python 저장소): Serena 단독은 바닐라 대비 토큰 +60%, 정확도는 모든 구성이 같았다.

**알 수 없는 것**

- 약한/오픈웨이트 모델에서 이득이 더 큰지 직접 비교한 자료를 찾지 못했다.
- 혼합 형식 스택에서의 효과는 문서로 판단할 수 없다.

### 5.3 추가 가치가 그럴듯한 조건과 중복이 큰 조건

| 그럴듯한 조건 | 중복이 크거나 손해인 조건 |
|---|---|
| 파일 간 rename, 참조 추적처럼 정확한 심볼 의미가 필요한 작업 (단, agent 내장 LSP와 겹침) | 중소 저장소의 국소 편집 |
| "누가 호출하나", 의존 체인 같은 구조 질의 | 전체 소스 맥락이나 완전한 패턴 매칭이 필요한 질의 |
| 대규모 저장소 | 모델이 도구를 무시하고 grep으로 돌아가는 경우 |
| 토큰과 속도가 제약인 환경 (C가 해당할 수 있으나 추론일 뿐, 실측 필요) | 정적 분석 밖의 연결이 핵심인 코드 |

---

## 6. 새로 볼 만한 것 (질문 3)

과거 목록에 없었고 지금 조사 대상에 넣어야 하는 것들이다.

| 항목 | 왜 중요한가 | 상태 |
|---|---|---|
| **OpenCode** | 모델 비종속. Bedrock·Azure·Vertex·로컬 엔드포인트를 같은 설정 구조로 지원. 관리 설정과 provider allowlist 제공. B와 C 양쪽에 걸치는 후보 | v1.18.34 (2026-09-30), MIT **[재확인]**. Windows 네이티브 실행이 가능하고, WSL은 공식 문서의 권장 경로이지 필수 조건이 아니다 **[재확인]** |
| **Codex CLI** | Bedrock·Azure 지원, 로컬 provider(`ollama`, `lmstudio`) 내장, Windows 네이티브 샌드박스 | Apache-2.0. 게이트웨이는 Responses API 호환 필수. Windows 샌드박스 실패 이슈 반복 |
| **Copilot CLI 오프라인 모드** | `COPILOT_OFFLINE=true` + 로컬 provider면 지정한 엔드포인트로만 통신한다고 문서화 | 독점 라이선스. 기본은 구독과 SaaS 결속 |
| **Cline** | VS Code 확장 + CLI. LG CNS와 엔터프라이즈 협업 발표(2026-06, 보도자료 수준)로 국내 SI 선례 | Apache-2.0. 중앙 설정은 Cline 호스팅 콘솔 의존 |
| **pi** | 의도적으로 최소화한 하네스. "얇은 하네스" 쪽의 실물 대조군 | MIT |
| **Agent Skills 오픈 표준** | 40개 이상 agent가 지원 클라이언트로 등재. 사내 지식 패키징을 agent 선택과 분리할 수 있음 | 등재와 실제 호환은 별개. 실측 필요 |
| **AGENTS.md** | 여러 agent가 공통으로 읽는 지침 파일 | 사실상 공통 포맷 |
| **스펙 주도 개발 툴킷** (Spec Kit, OpenSpec, BMAD) | 관심은 큼 | 독립적 가치 증거는 약함. Thoughtworks 리뷰는 "대다수 실제 코딩 문제에 맞지 않는다"고 평가 |
| **교차 모델 리뷰** | 사용자의 Claude Code ↔ GPT 관행과 같은 방향 | Cognition(벤더)이 "프런티어 모델 간 교차 자문은 잘 된다"고 증언. 독립 검증 없음 |
| **Orca** (`stablyai/orca`) | Claude Code·Codex·OpenCode·Pi 같은 CLI agent를 worktree 단위로 나란히 돌리는 상위 운용 환경(ADE). coding 능력을 높이는 도구가 아니라 여러 agent를 사람이 운용하는 층이다. GPT ↔ Claude Code 왕복 방식을 조직용으로 옮길 때 가치가 있는지 확인할 후보 | **1차 조사에서 놓쳤고 GPT 교차검토로 추가했다.** v1.4.220 (2026-10-04), MIT, Windows 설치본 제공(코드 서명), 익명 텔레메트리 opt-out **[재확인]**. 설치 우선순위를 뜻하지 않는다 |

**지속성 리스크의 실례**: Roo Code는 저장소가 보관 처리됐고(2026-05-15) **[재확인]**, Continue는 README에 "더 이상 활발히 유지되지 않으며 읽기 전용"이라고 적혀 있다 **[재확인]**. Aider는 2025-08 이후 릴리스가 없다. Gemini CLI는 Antigravity CLI(비공개 소스)로 전환 중이며 엔터프라이즈·유료 API 키 사용자만 계속 지원된다 **[재확인]**. 2025년의 유력 후보가 1년 만에 사라지거나 바뀌는 영역이므로, 여러 개발자에게 표준으로 배포할 때 **도구 교체 비용**을 고려해야 한다.

---

## 7. "agent 주변 scaffolding이 효과가 있는가"에 대한 실증 근거

### 7.1 같은 모델, 다른 하네스

| 발견 | 출처 | 주의 |
|---|---|---|
| 같은 모델이 벤더 하네스와 범용 하네스에서 점수가 다름. 벤더 하네스가 항상 우위는 아님 | Terminal-Bench 2.1 리더보드 (Snorkel 페이지 경유) | 상위권에 오픈웨이트 모델 없음 |
| 오픈웨이트 2종 × 하네스 3종: 통과율 차이 0~8pp(대부분 신뢰구간이 0 포함), 해결당 토큰은 최대 40배 차이 | arXiv 2607.22585 | 50개 과제. 하네스는 정답률보다 비용을 크게 바꿈 |
| 5개 모델 × 4개 하네스: 모델 순위가 하네스에 따라 뒤집힘. 한 오픈웨이트 모델은 구조화된 환경에서 +5.6~11.1 | arXiv 2610.00917 | 2026-10-01 제출, 미심사 |

### 7.2 지침 파일과 skills

- **지침 파일**: 결과가 엇갈린다. ETH 연구(arXiv 2602.11988)는 성공률을 대체로 올리지 못하고 비용만 20% 넘게 늘었다고 본다. 다른 연구(arXiv 2601.20404, 소표본)는 실행 시간과 토큰이 줄었다고 본다. 공통분모는 "긴 저장소 개요보다 비표준 규칙과 명령만 담은 짧은 파일이 낫다" 정도다.
- **Skills**: SkillsBench(arXiv 2602.12670)에서 큐레이션된 skill로 평균 33.9% → 50.5%. 집중형 skill이 포괄형 묶음보다 낫다. 소프트웨어 엔지니어링 도메인의 이득이 상대적으로 작고 일부 과제는 악화됐다는 점은 이쪽에서는 **[2차]**였으나 GPT 독립 조사에서도 확인됐다. 따라서 질문은 "Skills가 유효한가"가 아니라 "좁고 구체적인 개발 skill이 실제 추가 가치를 갖는가"다.

### 7.3 멀티에이전트와 하네스 두께

- arXiv 2512.08296: 멀티에이전트는 분해 가능한 과제에서 +80.8%, 순차 계획 과제에서 −70.0%. 코딩은 순차·도구 집약에 가깝다.
- Cognition(벤더): 통하는 구조는 "여러 agent가 판단을 보태되 쓰기는 단일 스레드". 병렬 쓰기는 여전히 실패한다.
- Anthropic(벤더): 모델이 강해지자 일부 구조를 제거했지만, 이를 "단순화"가 아니라 "경계가 바깥으로 이동"이라고 표현한다. "강해지면 얇아진다"와 "새 영역에는 다시 필요하다"가 공존한다.

### 7.4 약한 모델과 scaffolding

- **지지**: arXiv 2609.20804는 컨텍스트 관리가 창이 작을수록 가치가 커지고, 사전 정의 도구는 bash에 약한 모델에 도움이 된다고 본다. arXiv 2607.08938은 자동 하네스 최적화로 소형 모델 다수가 개선됐다고 본다(단, 코딩이 아닌 비즈니스 워크플로).
- **한계**: arXiv 2607.22585에서 하네스 간 정확도 차이는 작았다. AgentFloor(arXiv 2605.00334)는 소·중형 오픈웨이트 모델이 단기 도구 사용은 되지만 장기 계획에서 격차가 난다고 본다.
- **찾지 못한 것**: 구조화 워크플로나 LSP 도구가 로컬 모델의 실무 코딩 성공률을 올린다는 직접 증거.

### 7.5 현장 생산성

- **METR 후속 연구**(2026-02) **[재확인]**: 기존 참가자의 완료 시간 변화 추정 −18%(신뢰구간 −38%~+9%), 신규 참가자 −4%(−15%~+9%). AI 사용 시 빨라지는 방향이지만 구간이 0을 포함하고, METR 스스로 선택 효과 때문에 "매우 약한 증거"라고 밝혔다.
- **Microsoft 관찰 연구**(arXiv 2607.01418): CLI agent 도입자의 병합 PR이 약 24% 늘었다. 인과가 아니고 PR 수는 가치의 대리 지표다.

---

## 8. 환경별 적합성 (질문 4)

### 8.1 Agent별 환경 적합성

| Agent | A (제약 적음) | B (enterprise managed) | C (완전 격리) |
|---|---|---|---|
| **Claude Code** | 전체 기능 | Bedrock·Vertex·Foundry·게이트웨이 공식 지원. 로컬 루프 유지 | **비-Claude 모델 라우팅은 공식 비지원** **[재확인]**. 로컬 서버가 Anthropic 호환 API를 제공하면 기술적으로 연결은 되나 벤더 지원 밖 **[2차]** |
| **Codex CLI** | 전체 기능 | Bedrock 내장 provider, Azure 설정 가능 | 로컬 provider 내장. Responses API 호환 서버 필요 |
| **GitHub Copilot** | 전체 기능 | 엔터프라이즈 BYOK는 Copilot 서버 경유, 인터넷과 라이선스 필수 | CLI 오프라인 모드만 해당 |
| **Cursor** | 전체 기능 | 자체 키를 써도 모든 요청이 Cursor 백엔드를 경유 | 부적합 |
| **Gemini CLI** | 제품 전환 중 | Vertex 경유 | 공식 지원 아님 |
| **OpenCode** | 사용 가능 | Bedrock·Azure·Vertex·임의 호환 엔드포인트 | 로컬 엔드포인트 문서화 |
| **Cline** | 사용 가능 | Bedrock·Vertex·Azure·LiteLLM | 로컬 엔드포인트 문서화. 중앙 설정은 SaaS 콘솔 의존 |

### 8.2 A → B에서 잃는 것 (문서로 확인된 범위)

- **벤더 호스팅 기능**: 웹 검색(Claude Code on Bedrock, Codex on Bedrock Runtime), 클라우드·백그라운드 agent, 호스팅 코드리뷰, fast mode.
- **벤더 계정 기반 중앙관리**: Claude server-managed settings, Codex cloud-managed 정책, Cline 원격 설정. 로컬 파일·레지스트리 정책은 남는다.
- **최신 모델 반영 시점과 리전 제약**: 서울 리전에는 Opus 5와 Sonnet 5가 있고, Haiku 4.5와 Opus 5.5는 해당 공지에 없다 **[재확인]**. Claude Code의 Bedrock 기본값은 교차 리전 프로파일이므로 서울 고정을 원하면 모델 ID를 명시해야 한다.
- **유지되는 것**: 탐색, 편집, 빌드, 테스트, MCP, hooks, skills, plugins 같은 로컬 agent 루프. Claude Code 문서는 이들이 "모든 provider에서 동작한다"고 적는다.
- **교차 모델 검토**: A에서 관찰된 Claude ↔ GPT 왕복은 B에서 두 벤더 모델이 모두 승인된 엔드포인트에 있어야 가능하다. Bedrock에는 양쪽 모델이 올라와 있다고 조사됐으나 리전별 가용성이 다르다.

### 8.3 B → C에서 잃는 것

- **프런티어 모델 자체**: NIST CAISI 평가(2026-05)는 최상위 오픈웨이트 모델이 프런티어보다 약 8개월 뒤처진다고 본다. SWE-bench Verified에서는 74% 대 81%지만 장기·비공개 과제에서는 44% 대 78%로 격차가 크다. 벤치마크에 따라 결론이 달라진다.
- **벤더 공식 지원**: Claude Code와 Cursor가 사실상 빠진다.
- **도구 호출 신뢰성**: 툴콜 형식 오류, 파서 불일치, 서빙 스택의 기본 컨텍스트가 작아 조용히 잘리는 문제가 보고된다(이슈·커뮤니티 수준).
- **인프라 부담**: 모델 서빙 스택과 GPU. 하드웨어 수치는 전부 **[2차]**라 이 문서에서 산정 근거로 쓰지 않는다.

상업 이용이 깨끗한 오픈웨이트 후보(Apache/MIT 태그 확인)는 Qwen 계열, GLM-5.2, DeepSeek V4, Devstral Small 2, gpt-oss, Gemma 4다. Kimi K3, MiniMax M3, GLM-5.3, Devstral-2-123B는 `other` 라이선스라 조항 확인이 필요하다.

### 8.4 B 또는 C에서 A의 경험을 보존하려면 무엇이 추가되는가

증거로 말할 수 있는 범위만 적는다.

| 환경 | 추가되는 구성요소 | 근거 수준 |
|---|---|---|
| **B** | 승인된 엔드포인트 또는 LLM 게이트웨이, 모델 ID·리전 고정, 로컬 파일/레지스트리 기반 정책 배포, 사설 plugin·skill 저장소, 설치본과 업데이트의 내부 배포 | 문서로 확인 |
| **B** | 웹 검색 대체 수단 | 손실은 문서로 확인. 대체 수단은 조사하지 않음 |
| **C** | 모델 서빙 스택과 GPU, 로컬 엔드포인트를 공식 지원하는 agent로의 교체, 서빙 측 컨텍스트·툴콜 설정 | 문서로 확인 |
| **C** | 모델 격차를 메우는 scaffolding(워크플로 강제, code intelligence, 컨텍스트 절약 기법) | **가설 단계.** 7.4절처럼 증거가 엇갈리고 코딩 실무의 직접 증거가 없다 |

지시서가 전제하지 말라고 한 다섯 가지에 대한 현재 답은 다음과 같다.

- "제약이 강할수록 thick harness가 필요하다": 확인되지 않았다.
- "약한 모델에는 structured workflow가 필요하다": 부분 지지, 코딩 실무 증거 없음.
- "A의 multi-model 방식이 최적이다": 벤더 증언 1건뿐이다.
- "B가 현실적 최종안이다": 기술적으로는 로컬 루프가 유지된다는 점까지만 확인했다. 최종안 여부는 이 조사의 범위 밖이다.
- "C에서는 최신 AI 개발방식을 재현할 수 없다": 재현 수단은 문서상 존재한다. 어느 수준까지 재현되는지는 실측 없이는 알 수 없다.

---

## 9. 배포 가능성

중앙관리 플랫폼 설계가 아니라 각 후보가 실제로 제공하는 기능의 기록이다.

### 9.1 Agent

| 후보 | Windows 설치 | 오프라인 설치·업데이트 | 설정과 정책 | 엔드포인트 전환 |
|---|---|---|---|---|
| **Claude Code** | 네이티브, 관리자 권한 불필요. 설치 스크립트·winget·npm. 네이티브에서는 샌드박스 미지원(WSL2 필요) | 서명된 바이너리 자체 배포 가능. 자동 업데이트 차단과 버전 범위 강제 설정 제공 | user / project / managed. Windows는 `managed-settings.json` 또는 레지스트리 정책(GPO·Intune 템플릿). 사설 마켓플레이스와 허용 목록 | settings의 `env` 블록. C는 비지원 |
| **Codex CLI** | 네이티브 설치 스크립트, npm | 설치 스크립트가 외부 저장소에서 받음. 내부 배포 방식은 미확인 | 사용자·프로젝트 `config.toml`, `%ProgramData%` 아래 강제 정책 파일 | `model_provider` 한 줄. B·C 같은 구조 |
| **Copilot CLI** | 네이티브, PowerShell 6+ 필요. winget·npm | 오프라인 모드에서 자동 업데이트·텔레메트리·GitHub 인증 생략 | 조직 정책은 GitHub 서버 측. 로컬 관리 파일 미확인 | 환경 변수 2개 |
| **Cursor** | 설치본, 무인 설치 | 업데이트 정책 있음. 실행에 Cursor 서버 필수 | ADMX 그룹 정책 | 대시보드 설정 |
| **OpenCode** | 네이티브 가능하나 **WSL 권장** **[재확인]** | 자동 업데이트 끄기, 사설 npm 레지스트리 | 프로젝트 `opencode.json`, `%ProgramData%` 관리 설정(최우선), provider allowlist | `provider` 블록 교체 |
| **Cline** | VS Code 확장(VSIX), CLI는 npm | VSIX 수동 배포 | 중앙 설정은 호스팅 콘솔 의존 | 확장 설정 |

### 9.2 과거 후보

| 후보 | 배포 관점의 사실 |
|---|---|
| **gstack** | `git clone` 후 4천 줄대 bash `setup` 실행. Bun, Playwright Chromium 다운로드 필요. Windows는 Git Bash 또는 WSL. 팀 모드는 GitHub `main`에서 자동 업데이트하는 구조라 **버전 고정과 반대 방향**이다. 서명되지 않은 exe가 Smart App Control에 차단되는 이슈, 브라우저가 프록시 환경 변수를 따르지 않는 이슈가 열려 있다. 오프라인 설치는 문서화되지 않았다 |
| **Superpowers** | markdown skill과 hook 하나라 구조가 단순하다. 태그 릴리스가 있어 내부 미러와 버전 고정이 구조적으로 가능하다(README에 안내는 없음). Windows에서는 hook이 Git Bash를 요구하고 관련 문제가 반복됐다 |
| **Serena** | uv + Python 3.13, 언어별 언어 서버. Java는 최초 실행 시 대용량 외부 다운로드. GPL 전환으로 사내 수정·재배포 전 법무 확인 필요 |
| **codegraph 계열** | 번들 바이너리라 설치는 가볍다. 일부 도구는 Defender 오탐을 스스로 언급 |

### 9.3 배포에서 드러난 선행 조건

실제 스택과 무관하게, 환경 측에 먼저 물어야 답이 갈리는 항목이다.

- **WSL2 또는 컨테이너 허용 여부**: 샌드박스(Claude Code, Cursor)와 OpenCode 권장 경로가 여기에 걸려 있다.
- **서명되지 않은 실행 파일 정책**: gstack, 일부 code intelligence 바이너리.
- **최초 실행 시 외부 다운로드**: Playwright Chromium, 언어 서버, VSIX.
- **npm·PyPI 내부 미러 유무**: 대부분의 후보가 여기에 의존한다.
- **프록시 인증 방식**: Claude Code는 NTLM/Kerberos를 직접 지원하지 않는다.

---

## 10. 현재 시점의 판단 (질문 5)

하나의 stack을 고르지 않는다. 증거가 지지하는 범위에서만 분류한다.

### 10.1 그대로 쓸 가치가 높은 것

- **Agent의 기본 기능 그 자체**: 계획, 탐색, 편집, 빌드·테스트 반복, 서브에이전트, 리뷰. 5종 모두 내장했고 B에서도 유지된다.
- **저장소에 체크인하는 짧은 지침 파일과 프로젝트 설정**: 모든 agent가 지원한다. 단 "길고 포괄적인 개요"는 근거가 불리하므로, 비표준 규칙과 빌드·테스트 명령 위주로 한정할 때에 한한다.
- **조직 managed policy 계층**: 여러 PC에 동일 환경을 강제하는 수단으로 5종 모두 제공한다.
- **Agent Skills 포맷**: 여러 agent에 걸쳐 쓸 수 있는 유일한 공통 패키징이다. 내용의 효과는 skill마다 다르다.

### 10.2 특정 조건에서만 가치가 있는 것

- **Agent 내장 LSP / Serena**: 정적 타입 언어의 파일 간 rename·참조 추적. 언어 서버가 지원하는 범위 안에서만. Serena는 GPL과 오프라인 다운로드 문제가 따라온다.
- **그래프 계열**: 대규모 저장소의 구조 질의, 토큰이 제약일 때. 정답률 개선은 입증되지 않았다.
- **Graphify의 비-코드 범위**: 문서·SQL 스키마·설정까지 묶는 knowledge graph 성격은 Serena·CodeGraph와 다른 고유 영역이다. 다만 비-코드 의미 추출은 모델 API를 쓰므로 C에서는 로컬 모델로 돌려야 하고, 용도는 편집 루프보다 저장소 이해 쪽이다.
- **Superpowers류 프로세스 규율**: 검증 누락이 실제 문제로 관찰될 때. 비용과 소요 시간이 늘어난다.
- **gstack의 고유 부분**: 브라우저 QA 루프, 교차 모델 리뷰. 네트워크와 외부 API 의존이 커서 B·C에서는 일부가 깨진다.
- **OpenCode, Codex CLI 등 모델 비종속 agent**: B와 C가 미확정이거나 C가 확정될 때.
- **멀티에이전트**: 분해 가능한 과제, 읽기·검토 역할. 병렬 쓰기는 불리하다.

### 10.3 현재 agent 기능과 중복이 큰 것

- 방법론 팩의 계획, 리뷰, 서브에이전트 오케스트레이션, 메모리, 안전장치 부분.
- 별도 repo map, 벡터 RAG 인덱스(특히 외부 임베딩 API가 필요한 것).
- 코드 작성·디버깅 용도의 Graphify.

### 10.4 추가 검증이 필요한 것

문헌으로는 답이 나오지 않아 실제 저장소에서 만져봐야 하는 질문이다. 검증 방법은 이 문서에서 설계하지 않는다.

1. 환경 C에서 오픈웨이트 모델 + 모델 비종속 agent 조합이 실제 FE+BE 저장소에서 어느 수준인가.
2. 방법론 팩이나 code intelligence가 약한 모델의 격차를 실제로 메우는가.
3. Windows 네이티브 환경에서 각 agent의 실사용 품질(셸, 경로, 샌드박스).
4. 실제 스택의 비-코드 연결(매퍼, 템플릿, 독자 UI 포맷)을 어떤 도구가 따라가는가.
5. 프로세스 규율의 순효과(결함 감소 대 시간·비용 증가).
6. 교차 모델 리뷰의 효과 크기.
7. Agent Skills가 agent 간에 실제로 호환되는 정도.

---

## 11. 미검증·상충 항목

GPT 결과와 대조할 때 먼저 확인할 목록이다.

- **Continue의 상태**: README는 "읽기 전용"이라고 하지만 저장소는 보관 처리되지 않았고 최근 push가 있다 **[재확인]**. Cursor 인수설은 **[2차]**.
- **Gemini CLI**: 전환 공지와 달리 저장소는 2026-09-29에도 릴리스했다 **[재확인]**. 엔터프라이즈 지속 지원 범위의 실제 상태가 불명확하다.
- **Cursor**: 시맨틱 인덱스 축소의 정확한 범위, Windows 샌드박스 방식, 인덱스의 원격 저장 여부.
- **Codex**: 텔레메트리·프록시·인증서 설정 키, Windows 샌드박스 세부.
- **Claude Code를 로컬 모델에 연결하는 방식**: 서빙 스택 측 문서는 **[2차]**. 벤더 비지원이라는 점만 재확인했다.
- **오픈웨이트 벤치마크 수치**: 벤더 자가 보고와 독립 평가가 어긋난다. 2차 블로그 수치는 쓰지 않았다.
- **하드웨어 산정**: 전부 **[2차]**.
- **Azure 한국 리전 가용성**: 미확인. AWS 서울만 원문을 확인했다.
- **gstack·Superpowers의 Bedrock/Azure/오픈웨이트 동작**: 문서가 없다. 본문의 호환성 서술은 구조에서 추론한 것이다.
- **저자 측정 수치 전반**: gstack 토큰 비용, Superpowers 속도·비용 개선, codegraph 호출 감소, Graphify 압축률.
- **SkillsBench 세부 수치**: 검색 요약과 초록이 다르다(버전 차이로 추정).
- **METR 수치의 부호**: 원문 요약 기준 "음수 = AI 사용 시 더 빠름"으로 읽었다. 대조 시 원문 표현을 다시 확인할 것.
- **모델명 표기**: 일부 출처의 모델 버전 표기는 조사 갈래의 보고를 그대로 옮겼고 개별 확인하지 않았다.

---

## 12. 후속 검토 주제

이번 조사 범위 밖이라 기록만 한다.

- LLM 게이트웨이의 인증(SSO, NTLM)과 감사 로깅: enterprise governance 영역.
- 자체 인프라형 agent 플랫폼(서버형 agent, 중앙 orchestration): 중앙 플랫폼 영역.
- MCP 사설 레지스트리와 거버넌스.
- 환경 C의 GPU 산정과 서빙 운영: 인프라 설계 영역.
- AI 도입 후 조직 수준 생산성 측정 방식.

---

## 13. 주요 출처

### 저장소 (2026-10-04 `gh api` 조회)

- https://github.com/garrytan/gstack
- https://github.com/obra/superpowers
- https://github.com/oraios/serena
- https://github.com/colbymchenry/codegraph
- https://github.com/Graphify-Labs/graphify
- https://github.com/DeusData/codebase-memory-mcp
- https://github.com/anomalyco/opencode
- https://github.com/cline/cline
- https://github.com/earendil-works/pi
- https://github.com/RooCodeInc/Roo-Code
- https://github.com/continuedev/continue
- https://github.com/Aider-AI/aider
- https://github.com/google-gemini/gemini-cli
- https://github.com/openai/codex

### 공식 문서

- Claude Code: https://code.claude.com/docs/en/llm-gateway , https://code.claude.com/docs/en/third-party-integrations , https://code.claude.com/docs/en/amazon-bedrock , https://code.claude.com/docs/en/managed-settings , https://code.claude.com/docs/en/sandboxing , https://code.claude.com/docs/en/plugins/code-intelligence
- Codex: https://learn.chatgpt.com/docs/amazon-bedrock , https://learn.chatgpt.com/docs/enterprise/managed-configuration , https://learn.chatgpt.com/docs/enterprise/gateway-compatibility , https://learn.chatgpt.com/docs/windows/windows-sandbox
- Gemini CLI: https://geminicli.com/docs/cli/enterprise/ , https://github.com/google-gemini/gemini-cli/discussions/27274
- Copilot: https://docs.github.com/en/copilot/concepts/models/bring-your-own-key , https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli
- Cursor: https://cursor.com/docs/enterprise , https://cursor.com/help/models-and-usage/api-keys
- OpenCode: https://opencode.ai/docs/windows-wsl/ , https://opencode.ai/docs/config/ , https://opencode.ai/docs/providers/ , https://opencode.ai/docs/lsp/
- Cline: https://docs.cline.bot/enterprise-solutions/configuration/remote-configuration/overview
- Agent Skills: https://agentskills.io/home
- Serena: https://oraios.github.io/serena/01-about/020_programming-languages.html , https://github.com/oraios/serena/issues/1414
- AWS 서울 리전: https://aws.amazon.com/about-aws/whats-new/2026/09/claude-region-expansion-in-sk/

### 논문·평가

- 지침 파일: https://arxiv.org/abs/2602.11988 , https://arxiv.org/abs/2601.20404 , https://arxiv.org/abs/2608.25241
- Skills: https://arxiv.org/abs/2602.12670
- 하네스 효과: https://arxiv.org/abs/2607.22585 , https://arxiv.org/abs/2610.00917 , https://arxiv.org/abs/2606.12344 , https://arxiv.org/abs/2609.20804
- 약한 모델: https://arxiv.org/abs/2607.08938 , https://arxiv.org/abs/2605.00334
- 멀티에이전트: https://arxiv.org/abs/2512.08296
- 코드 탐색: https://arxiv.org/abs/2603.27277 , https://arxiv.org/html/2606.07297v1
- 현장 생산성: https://metr.org/blog/2026-02-24-uplift-update/ , https://arxiv.org/abs/2607.01418
- 오픈웨이트 격차: https://www.nist.gov/news-events/news/2026/05/caisi-evaluation-deepseek-v4-pro
- 리더보드: https://snorkel.ai/leaderboard/terminal-bench-2-1/

### 엔지니어링 글·리뷰

- https://www.anthropic.com/engineering/harness-design-long-running-apps
- https://cognition.com/blog/multi-agents-working
- https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- https://cursor.com/blog/semsearch
- https://cline.bot/blog/why-cline-doesnt-index-your-codebase-and-why-thats-a-good-thing
- https://jxnl.co/writing/2025/09/11/why-grep-beat-embeddings-in-our-swe-bench-agent-lessons-from-augment/
- https://blog.fsck.com/2026/09/21/superpowers-6.4/
- https://github.com/obra/superpowers/issues/2017
- https://claude-codex.fr/en/content/garry-tan-stack-claude-code/

---

# Addendum — 실물 진입 전 마지막 외부환경 조사 (2026-10-04)

범위는 지시서 추가분의 3가지다: C 환경 전제 검증, 국내 실제 사례, 비용·지원 구조. GitHub 도구 탐색은 하지 않았다. 근거 수준 표기는 본문 0.2절과 같다.

## A1. C 환경 전제 판정: "유지"가 아니라 "수정"

**수정 전**: C = 온프렘 오픈웨이트 모델뿐.
**수정 후**: C의 기본은 오픈웨이트 모델이고, 예외로 Google Distributed Cloud(GDC) air-gapped의 Gemini가 있다. Claude와 GPT 본 모델을 완전 격리 환경에서 쓰는 경로는 찾지 못했다.

| 경로 | 모델 | 격리 수준 | 상태 | 한국 |
|---|---|---|---|---|
| **Google GDC air-gapped** | Gemini 2.5 Pro / Flash, Gemma **[재확인]**. 공개 클라우드 최신 세대보다 뒤로 보임 | 고객 데이터센터 완전 단절 | GA (2025-08-28) **[재확인]**. Google 공급 전용 하드웨어, 영업 계약 | 삼성SDS가 국내 첫 GDC 제공을 발표(2026-04, 보도). 공공·국방·금융 우선. 일정·가격 미확인 |
| Google GDC connected | 최신 Gemini Flash | 고객 구내 + 벤더 컨트롤 플레인 연결 | Preview | 위와 같음 |
| AWS AI Factories | 모델명 미공개 | 고객 데이터센터에 놓이나 AWS가 운영하는 전용 리전. 단절형이 아님 | 수주형, 정부·초대형 대상 | 국내 사례 없음 |
| Microsoft Foundry Local on Azure Local (단절) | Phi, Mistral, Qwen, gpt-oss 등 **오픈웨이트만**. GPT 본 모델 없음 | 완전 단절 | Preview | 한국 한정 정보 없음 |
| Anthropic | 온프렘 가중치 제공 없음 (문서에 해당 옵션 부재) | — | — | Bedrock 서울 리전 경유뿐(= B) |
| OpenAI | 온프렘에 둘 수 있는 것은 오픈웨이트 gpt-oss | — | — | — |
| 국내 구축형 (네이버 뉴로클라우드, KT 어플라이언스 등) | 자체 모델 | 완전 단절 | 제공 중 **[2차]** | 국내. 에이전트형 코딩에서 프런티어급이라는 근거는 찾지 못함 |

판정에 붙는 조건:

- **GDC Gemini가 coding agent에 쓸 만한지는 미확인이다.** GDC air-gapped 문서 개요에 "최대 32,000 토큰 컨텍스트"라는 문구가 있다 **[재확인]**. 이것이 Gemini 2.5에도 적용된다면 에이전트형 코딩에는 큰 제약이다. 어떤 API 형식을 제공하는지, 어떤 agent가 붙는지도 문서에서 확인하지 못했다.
- **도달 가능성이 낮다.** 전용 하드웨어와 영업 계약이 필요하고 공공·국방·금융이 우선이다. 유통 그룹 차원의 도입이면 가능하지만 협력사 단독으로는 어려워 보인다.
- **Claude Code와 Codex를 프런티어 모델로 쓰는 것은 C에서 여전히 불가능하다.** 본문 8장의 결론은 그대로다.
- **Bedrock 서울 리전은 C가 아니라 B다.** 리전 내 처리와 사설 연결을 써도 퍼블릭 리전이다.

실물 단계에 미치는 영향: C의 실물 후보는 여전히 "오픈웨이트 모델 + 모델 비종속 agent"다. GDC는 실물로 만져볼 수 없으므로 고객 측 협의 카드로만 기록한다.

## A2. 국내에서 실제로 열린 형태

제품명보다 "어떤 망·모델 위치·개발 환경으로 열었는가"를 기준으로 정리했다.

### 규제가 유통사에 걸리는 범위

- 금융 망분리 규정(전자금융감독규정)은 **유통사에 적용되지 않는다.**
- 공공 N2SF도 민간에는 참조 모델일 뿐이다.
- 유통사에 실제로 걸리는 것은 개인정보위 「개인정보의 안전성 확보조치 기준」이고, 2025-10-31 개정으로 일률적 인터넷망 차단이 위험분석 기반으로 완화됐다. 차단이 유지되는 대상은 개인정보처리시스템 접근권한 설정 단말 등 특정 단말이다.
- 따라서 **개발 단말 전체를 폐쇄망으로 두는 것은 법적 의무보다 사내 정책일 가능성이 높다.** 고객사에 확인해야 한다.

### 열린 형태 네 가지

| 형태 | 대표 사례 | 망·모델·개발 환경 | 출처 수준 |
|---|---|---|---|
| **통제 게이트웨이 경유 클라우드 프런티어 모델** | KB증권 (2026-06 금융보안원 보안대책 평가 "적합") **[재확인]** | 망분리 예외구간 단말 → 중앙 허브·LLM 게이트웨이 → 클라우드. 단말의 직접 연결 차단. 행사 발표 기준 Claude Code + MCP 허브 + Amazon Bedrock **[재확인]** | 적합 판정은 공식 보도자료 기반 기사. 모델·도구명은 AWS 행사 발표(PR 성격) |
| 같은 유형 | 카카오뱅크 (2026-03 혁신금융서비스 지정, 보도) | 모든 트래픽이 자사 온프레미스를 거쳐 관리형 클라우드 엔드포인트(Bedrock Claude, Azure OpenAI)로 | 보도 |
| **내부망 온프레미스 모델** | NH농협은행, 롯데캐피탈 | 외부 차단 내부망에 구축형 모델, IDE 내 코드 어시스턴트 또는 웹 챗 | 보도·보도자료 |
| **기업용 SaaS 계약에 의한 전사 개방** | 삼성전자 (2026-06, 보도) | 2023년 사내 금지 → 기업용 계약으로 전환. 웹 챗 + 코딩 agent | 보도 |
| **공공 내부망형** | 범정부 AI 공통기반 | 내부망에 민간 AI 챗 2종. 개발자용이 아니라 챗 중심 | 정부 발표·보도 |

관찰:

- **규제 업종에서 "통제 없이 외부 SaaS를 개발 단말에 직접 연" 사례는 찾지 못했다.** 열린 곳은 전부 게이트웨이, 예외구간 단말, 이력 관리 같은 통제를 붙였다.
- **KB증권 구조는 본문의 환경 B와 같은 형태다.** 가장 엄격한 금융 규제 아래에서 "직접 연결 차단 + 중앙 게이트웨이" 조건으로 클라우드 프런티어 모델을 개발 단말에 열었다는 선례다.
- 유통 동종 업계에서는 신세계I&C가 개발 전 과정에 생성형 AI를 적용했다고 발표했으나 모델 위치가 불명확하다. 고객사 그룹의 개발자용 AI나 망 정책 공개 자료는 찾지 못했다.

### 설득 근거로 쓸 수 있는 것과 없는 것

- **쓸 수 있음**: KB증권·카카오뱅크의 게이트웨이 구조, 삼성전자의 금지 → 기업용 계약 전환, 규제 전반이 일률 차단에서 위험 기반으로 이동 중이라는 방향, 금융보다 약한 규제를 받는 유통사가 금융보다 닫혀 있을 법적 근거가 약하다는 점.
- **쓸 수 없음**: 벤더 보도자료의 생산성 수치, 금융권 1년 한시 완화(보안 목적 한정), 2026-04 SaaS 예외(사무용 한정, 생성형 AI 미포함), 공공 사례(챗 중심), 온프레미스 사례(클라우드 개방의 근거로는 반대 방향).

## A3. 비용·지원 구조 (얕게)

TCO 계산은 하지 않았다. 후보 선택을 뒤집을 수 있는 조건만 적는다.

- **좌석 제품도 순수 정액이 아니다.** Copilot(크레딧 초과 과금), Codex(크레딧), Claude Enterprise(좌석 + 사용량) 모두 좌석 위에 종량 요소가 있다. "좌석 = 예산 확정"은 성립하지 않는다.
- **클라우드 경유 시에는 좌석이 필요 없다.** Claude Code는 Bedrock·Foundry에서 클라우드 계정으로 토큰당 청구된다 **[재확인]**. Codex CLI와 OpenCode도 자체 엔드포인트로 쓸 수 있다.
- **벤더가 공개한 비용 기준선은 Anthropic 것 하나다.** "엔터프라이즈 배포 평균 개발자 1인당 활성일 약 $13, 월 $150~250, 90%의 사용자가 활성일 $30 미만"이며 소규모 파일럿으로 기준선을 잡으라고 권고한다 **[재확인]**. 다른 벤더의 대응 수치는 찾지 못했다.
- **캐시 수명이 채널마다 다르다.** 구독은 1시간, API 키·클라우드는 기본 5분이다 **[재확인]**. 클라우드 경유에서는 쉬었다 돌아온 첫 요청이 전체 재처리가 된다.
- **클라우드 경유 시 사용자별 비용 귀속은 직접 구성해야 한다.** Anthropic 분석 대시보드가 적용되지 않으므로 OpenTelemetry나 LLM 게이트웨이가 필요하다 **[재확인]**. KB증권 구조의 게이트웨이가 이 역할도 겸한다.
- **Cursor는 자체 키를 써도 Cursor 백엔드를 경유한다.** "고객 클라우드 계정만 경유" 요건이 있으면 탈락 사유다.
- **오픈소스 agent에도 상용 지원 경로가 있다.** OpenCode와 Cline 모두 Enterprise 상품이 있다. 가격과 SLA는 미확인이다.
- **온프렘은 서빙 소프트웨어 지원이 변수다.** vLLM은 커뮤니티 지원이고, NVIDIA AI Enterprise는 GPU당 라이선스에 벤더 지원이 포함된다.

### 협력사 계약 관점

- **재판매·중개 금지 조항이 있다.** Claude Code 약관은 고객이 최종 사용자를 대신해 사용량을 지불·재판매·중개하는 것을 금지한다. 협력사가 자기 계약으로 자사 개발자에게 배포하는 것은 가능하지만, 고객사에 사용량을 되파는 구조는 사전 확인이 필요하다.
- **고객사 클라우드 계정을 쓰면 계약 주체가 고객사가 된다.** 협력사는 자격증명만 받고, 이 경우 좌석형 제품은 구조상 쓸 수 없다.
- **개인 계정 혼입 위험이 있다.** 상용 약관에서는 학습에 쓰지 않지만 개인 구독 계정은 소비자 약관이다. 조직 로그인을 강제하는 관리 설정이 필요하다.
- 협력사 인력이 약관상 인가 사용자로 명시 허용되는지는 문서 간 서술이 달라 확인하지 못했다. 계약 전에 원문 확인이 필요하다.

## A4. 기존 결론 수정사항

| 본문 위치 | 수정 |
|---|---|
| 1장 8번, 8.3절 | "C = 오픈웨이트" → "C의 기본은 오픈웨이트. 예외로 GDC air-gapped Gemini가 있으나 도달 가능성과 coding agent 적합성은 미확인" |
| 8.4절 | B에서 추가되는 구성요소 중 "LLM 게이트웨이"는 선택이 아니라 국내 선례의 공통 요소다. 통제와 비용 귀속을 겸한다 |
| 10.1절 | 추가: 환경 B의 실물 형태는 "개발 단말 → 중앙 게이트웨이 → 리전 내 클라우드 모델"이며 국내 금융권 선례가 있다 |
| 12장 | 게이트웨이·감사 로그·입력 차단 등 통제 구조 설계는 후속 주제로 유지 |

## A5. 이 조사에서 미검증으로 남은 것

- GDC air-gapped의 현재 Gemini 버전, 32,000 토큰 제한의 적용 범위, API 형식, agent 호환성.
- 삼성SDS GDC의 출시 일정, 가격, 격리 유형.
- KB증권의 모델·도구명은 행사 발표에만 있고 공식 보도자료 기반 기사에는 없다. 혁신금융서비스 지정의 조문 근거도 원문 미확인.
- 카카오뱅크 지정은 보도 1건만 확인했다.
- 금융권 한시 완화 대상 명단이 출처마다 다르다.
- 신세계I&C 사례의 실제 모델 위치.
- 좌석 제품들의 엔터프라이즈 SLA, 국내 리셀러 청구 방식, Azure 한국 리전 모델 가용성.
- Bedrock/Azure 토큰 단가는 요약 도구가 반환한 수치가 의심스러워 인용하지 않았다.

## A6. Addendum 출처

- GDC: https://cloud.google.com/blog/topics/hybrid-cloud/gemini-is-now-available-anywhere , https://cloud.google.com/blog/topics/hybrid-cloud/google-distributed-cloud-at-next26 , https://docs.cloud.google.com/distributed-cloud/hosted/docs/latest/gdcag/application/ao-user/genai/genai-overview
- 삼성SDS·GDC: https://www.hankyung.com/article/2026042325841
- AWS AI Factories: https://aws.amazon.com/about-aws/global-infrastructure/ai-factories/faqs/
- Microsoft 단절형: https://blogs.microsoft.com/blog/2026/02/24/microsoft-sovereign-cloud-adds-governance-productivity-and-support-for-large-ai-models-securely-running-even-when-completely-disconnected/ , https://learn.microsoft.com/en-us/azure/azure-sovereign-clouds/private/foundry-local/concept-model-catalog
- 금융 규제: https://fsc.go.kr/po010101/86080 , https://fsc.go.kr/no010101/86745 , https://zdnet.co.kr/view/?no=20260420161504
- 개인정보 안전성 확보조치 기준 개정: https://www.newsis.com/view/NISX20251031_0003384788
- KB증권: https://zdnet.co.kr/view/?no=20260622102240 , https://www.itdaily.kr/news/articleView.html?idxno=241257
- 카카오뱅크: https://www.fntimes.com/html/view.php?ud=202603011954193271dd55077bc2_18
- 삼성전자: https://www.hankyung.com/article/2026062210881
- 비용·약관: https://code.claude.com/docs/en/costs , https://code.claude.com/docs/en/third-party-integrations , https://code.claude.com/docs/en/legal-and-compliance , https://docs.github.com/en/copilot/get-started/plans , https://cursor.com/docs/settings/api-keys , https://opencode.ai/docs/enterprise/ , https://docs.nvidia.com/ai-enterprise/planning-resource/licensing-guide/latest/licensing.html
