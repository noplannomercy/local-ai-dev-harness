# Harness v0.1 — 최소 잔존 Capability 식별 (Superpowers · gstack 대조)

작성: 2026-10-06. 기준선: `DEVELOPER-WALKTHROUGH.md` (v0.1.0) + `core/AGENTS.core.md` + `core/settings.core.json`.
대조 원본: Superpowers 6.3.0 (`~/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/`, 14 skill 전부), gstack (`~/.claude/skills/` 중 review·qa·qa-only·investigate·browse·design-review·spec·plan-eng-review·careful·health·retro·document-release).
판단 단위는 제품·Skill이 아니라 **행동**이다. 이 문서는 식별만 한다. 흡수·구현·실험 설계는 하지 않는다.

실측 근거로 쓴 것: `docs/e2e-2026-10-04/`, `docs/e2e-2026-10-05/`. 두 실행 모두 세션에 사용자 수준 Superpowers·gstack이 켜져 있었으므로, 아래에서 "실측에서 모델이 지시 없이 했다"는 서술은 **그 환경에서의 관찰**이다. Core만의 증거로 읽지 않는다.

---

## 1. 결론

- **KEEP-CANDIDATE: 4개**
- **HOLD: 6개**
- **DROP: 나머지 전부** (추출된 후보 약 70개 중)
- **현재 Harness를 지금 수정해야 하는가: 아니오**

Superpowers·gstack에서 추출한 행동 대부분은 (a) 3.2 분석 계약·공통 규칙 6줄과 같은 내용이거나, (b) 실측 두 번에서 모델이 지시 없이 이미 한 행동이거나, (c) 제품 구조(daemon·subagent·ledger·hook)에 묶인 것이었다. 남은 4개는 모두 **기준선이 비어 있거나 방향이 반대인 자리**에 있고, 모두 한두 문장으로 표현되며, 어느 것도 지금 추가할 근거(관찰된 결손)는 없다. 후속 시나리오에서 자연스럽게 확인되면 그때 본다.

---

## 2. KEEP-CANDIDATE

### K1. 구현 중 사람 몫의 결정을 대신 내렸으면, 결과 보고에 "결정한 것·이유"를 별도 항목으로 적는다

- **행동**: 승인 프롬프트에 없던 판단(설계 선택, 가정 확정, 모호한 요구의 해석, 발견한 결함의 처리)을 구현 중에 내렸으면 결과 파일에 "구현 중 결정한 것" 절로 분리해 적는다. 무엇을·왜·틀렸을 때 비용.
- **출처**: Superpowers `subagent-driven-development` — "Record every decision … `Ruling: <what> — <why> — <what it costs if wrong>` … A ruling that dies with the workspace was a decision made in secret." gstack `plan-eng-review/review-sections.md` — "never silently default to an option … list these as 'Unresolved decisions that may bite you later'."
- **기준선에 없는 부분**: 결과 파일 항목은 "변경 파일, 추가한 테스트, 실행한 검증과 결과, 확인하지 못한 것" 4개. 결정은 2단계(사람 승인) 이전 것만 다룬다. 승인 이후 구현 중 생기는 판단은 받을 자리가 없다.
- **왜 범용적으로 중요할 가능성이 있는가**: 10-04와 10-05는 같은 CR·같은 결정으로도 설계가 달랐다(정책 컴포넌트+Clock 빈 vs 엔티티 메서드). 10-05 사용자는 "권장안대로"로 위임했고, 결과 재확인(테스트 재실행)은 "형식적"이라고 느꼈다. 위임이 늘수록 사람이 봐야 할 것은 테스트 수가 아니라 **대신 내려진 결정**이다. 이것은 회사·프로젝트와 무관한 사람-agent 분업 구조의 문제다.
- **정직한 단서**: 모델은 이미 부분적으로 한다(10-04 결과서에 `@Named` 추가 이유, 10-05에 매퍼 미수정 이유가 적혀 있었다). 명시 실익은 "하느냐"가 아니라 "사람이 찾지 않아도 한 곳에 모여 있느냐"다.
- **확인 시나리오**: 다음 B 실행에서 사람이 위임형 승인("권장안대로")을 했을 때, 결과서만 읽고 구현 중 판단을 전부 파악할 수 있는가. 못 하면 필요 확인.

### K2. 버그 수정은 재현 테스트가 수정 전에 **실패하는 것을 본 뒤** 고치고, 수정 후 통과를 본다

- **행동**: 증상을 재현하는 테스트를 먼저 쓰고 실패(그것도 예상한 이유로)를 확인한 다음 고친다. 테스트를 나중에 썼으면 수정을 잠시 되돌려 실패를 확인한다.
- **출처**: Superpowers `systematic-debugging` Phase 4.1 "Create Failing Test Case … MUST have before fixing"; `verification-before-completion` "Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)". gstack `investigate` Phase 4.3 "**Fails** without the fix (proves the test is meaningful) / **Passes** with the fix".
- **기준선에 없는 부분**: 시나리오 C 한 줄은 "원인 추적 → 최소 수정 → 재현 테스트 → 회귀 확인"으로 **순서가 반대**다. 수정 후에 쓴 테스트는 실패할 수 있는지 아무도 확인하지 않는다. 기준선 전체에서 유일하게 방향이 어긋난 문장이다.
- **왜 범용적으로 중요할 가능성이 있는가**: 두 원본이 독립적으로 같은 규칙을 둔다. "통과하는 테스트"와 "결함을 잡는 테스트"의 차이는 언어·스택과 무관하다. 비용은 실행 한 번.
- **정직한 단서**: 시나리오 C는 한 번도 실행되지 않았다. 모델이 지시 없이 이 순서로 하는지 모른다.
- **확인 시나리오**: 시나리오 C 첫 실행. 후보 입력은 이미 있다 — 10-05에서 발견돼 미수정으로 넘긴 기존 결함(`POST /api/visits`가 petId를 보내도 400). 그때 agent가 재현 테스트의 선실패를 보이는지 관찰.

### K3. 같은 결함에 수정 시도가 3회 실패하면 멈추고 사람에게 알린다

- **행동**: 네 번째 수정을 시도하지 않는다. 시도한 것·실패 양상·의심되는 구조 문제를 보고하고 결정을 받는다.
- **출처**: Superpowers `systematic-debugging` Phase 4.4–4.5 "If ≥ 3: STOP and question the architecture … Discuss with your human partner before attempting more fixes." gstack `investigate` Phase 3.3 "If 3 hypotheses fail, STOP"; 공통 preamble "Escalate after 3 failed attempts".
- **기준선에 없는 부분**: 되묻는 규칙은 범위 확대 시에만 있다. 같은 자리에서 수정이 반복 실패할 때의 멈춤 조건이 없다.
- **왜 범용적으로 중요할 가능성이 있는가**: 두 원본이 숫자까지 같다(3). 이것은 "일단 통과하게 만들어"라는 압력 아래에서 모델이 수정을 겹쳐 쌓는 알려진 실패 양상을 겨냥한 것이고, 모델이 약해질수록(게이트웨이·Bedrock 경로의 다른 모델) 더 중요해진다. 한 문장이고 비용이 없다.
- **정직한 단서**: 두 실측 모두 한 번에 통과했으므로 이 상황은 관찰된 적이 없다. 10-04에서 MapStruct "Ambiguous mapping" 컴파일 오류를 1회 만에 해결한 것이 유일한 "실패 후 재시도" 기록이다.
- **확인 시나리오**: 시나리오 C, 또는 업무급 저장소에서 빌드·테스트가 한 번에 통과하지 않는 첫 사례.

### K4. "화면 확인"은 페이지를 여는 것이 아니라, 바뀐 상호작용을 실제로 수행하고 결과 상태와 콘솔 오류를 보는 것이다

- **행동**: 바뀐 화면을 열고 → 바뀐 동작(클릭·입력·제출)을 실제로 수행하고 → 그 결과 상태가 나타났는지 → 로드 후와 상호작용 후 콘솔에 새 오류가 없는지 확인한다.
- **출처**: gstack `qa` Rule 6 "Check console after every interaction. JS errors that don't surface visually are still bugs"; "If the change was interactive (forms, buttons, flows), test the interaction end-to-end"; `browse` Pattern 2 "fill → click (submit) → snapshot → is visible (success state present?)".
- **기준선에 없는 부분**: 공통 규칙은 "앱을 띄워 브라우저로 해당 화면을 확인"이고, 관찰표 7번 PASS 기준은 "해당 화면을 **열어** 확인한 기록". 도구 줄에 `snapshot`·`click`·`console`이 나열돼 있지만 그것이 요구인지 설명인지 구분되지 않는다. 즉 "확인"이 정의돼 있지 않아 **열기만 해도 PASS**다.
- **왜 범용적으로 중요할 가능성이 있는가**: FE 변경의 완료 조건을 "열었다"로 두면 7번 관찰 항목이 변별력을 잃는다. 콘솔 오류는 화면에 안 보이는 결함의 가장 싼 신호이고, 상호작용 수행은 "렌더링됐다"와 "동작한다"를 가른다. 현재 Core 도구(`playwright-cli`의 `click`·`snapshot`·`console`)만으로 된다. 추가 도구 없음.
- **정직한 단서**: 실제 FE 저장소에서 브라우저 확인은 한 번도 실행되지 않았다. 모델이 지시 없이 상호작용·콘솔까지 보는지 모른다. gstack의 나머지 QA 규칙(폼 실패 경로, 빈/로딩/오류 상태, 인접 페이지, 모바일 폭, 네트워크 실패)은 **이 최소 정의가 부족하다고 확인된 뒤에만** 본다 — HOLD.
- **확인 시나리오**: FE가 도는 저장소에서의 첫 UI 변경(`harness-v0.md` 7.7 #1). agent 보고가 "페이지를 열어 확인했다"에서 멈추면 필요 확인.

---

## 3. HOLD

| # | 행동 | 출처 | 다시 보는 조건 |
|---|---|---|---|
| H1 | 결과 보고 전 agent가 자기 diff를 승인된 계획과 대조(항목별 DONE/부분/미수행, 범위 밖 변경, 적대적 "운영에서 어떻게 실패하나" 1회) | gstack `review` Step 1.5·Plan Completion Audit·`specialists/red-team.md`; Superpowers implementer Self-Review | 사람 리뷰(3.4)가 못 잡은 결함이 한 번이라도 나올 때. 그때도 Claude Code 내장 `/code-review`가 먼저이고 별도 규칙은 그 다음 |
| H2 | 사람의 결정·피드백이 코드 사실과 충돌하면 구현 전에 근거를 들어 되묻는다. 확인 못 하면 "확인 못 함"이라고 말한다 | Superpowers `receiving-code-review` | 사람이 내린 결정이 틀렸는데 agent가 그대로 구현한 사례가 나올 때 |
| H3 | 스키마·공유 API 계약·데이터 변경 시 분석서에 마이그레이션·하위 호환·되돌리기 방법을 명시 | Superpowers `code-reviewer.md`; gstack `spec` §14, `specialists/data-migration.md` | 실제 고객 stack에서 DB 스키마나 공유 계약을 건드리는 첫 CR |
| H4 | 디버깅 보조 두 가지: ① 영향 파일의 최근 git 이력을 먼저 본다 ② 가설을 임시 로그·단언으로 확인한 뒤 고친다 | Superpowers `systematic-debugging` Phase 1.3·3; gstack `investigate` Phase 1.3·3.1 | 시나리오 C 실행 후, K2·K3만으로 부족하다고 보일 때 |
| H5 | 브라우저 QA 확장: 폼의 빈 값·잘못된 값 경로, 빈/로딩/오류 상태, 인접 페이지 회귀, 모바일 폭 | gstack `qa/references/issue-taxonomy.md`, `design-review` | K4가 확인된 뒤. 첫 FE 시나리오 전에는 올리지 않는다 |
| H6 | 시나리오 A에서 요구가 독립된 하위 시스템 여러 개면 세부 질문 전에 먼저 분해를 제안 | Superpowers `brainstorming` | 시나리오 A 첫 실행, 입력이 PRD급일 때 |

---

## 4. DROP

이유별로 묶는다. 개별 Skill 목록은 만들지 않는다.

**A. 3.2 분석 계약(7항목)·CR 서식과 중복**
- 요구 해석·모호점·가정 (항목 1) ← Superpowers brainstorming 모호성 점검, placeholder 자가 검사; gstack spec "ambiguity"
- 인수 기준 pass/fail 명시 ← CR 서식에 "인수 기준" 절이 이미 있고, 10-04에서 agent가 요구와 인수 기준의 30일 모순을 찾아냈다
- 영향 범위·같은 API/데이터 사용처·깨질 테스트 (항목 3) ← enum/상수 소비처 점검, API 계약 변경 점검, "what already exists"
- 기존 패턴 (항목 4), 대안과 선택 이유 (항목 5), 검증 계획 (항목 6) ← writing-plans 구조, spec 구조, 기대 출력 명시
- 위험과 사람 결정 (항목 7) ← 실패 모드 표, DONE_WITH_CONCERNS, 완료 상태 enum, out-of-scope 명시
- 범위 밖이 필요하면 먼저 묻기 (공통 규칙·관찰 4) ← 크기 분류·중간 재범위 지정, 계획과 현실이 어긋나면 멈추기, 5파일 초과 시 묻기, 발견한 문제를 한 문장으로 보고하기(10-05에서 기존 결함 발견 후 보고만 한 것이 관찰됨)
- 직접 확인/추정 구분 (항목 2)·미확인 분리 (공통 규칙) ← 리뷰 서술의 "evidence before claim", 재현 못 하면 수정 안 함

**B. 모델 기본 행동으로 실측에서 관찰됨 (지시 없이 수행)**
- 테스트 자체 설계: 10-05 구현 프롬프트에 테스트 목록이 없었는데 경계값 8개(시간대·윤년 포함)와 응답 경로별 컨트롤러 테스트를 스스로 설계했다 ← 테스트 품질 규칙 전반(변경 감지 테스트 금지, 미러 단언 금지, mock 단언 금지, 분기별 커버리지, 돌연변이 점검, 부정 경로 테스트). **관찰된 결손이 없어 명시할 근거가 없다.** 결손이 보이면 그때 항목 단위로 다시 본다
- 검증 범위 확장: 지시는 `test`였는데 `verify`(커버리지 기준)까지 돌렸다 ← "경고도 결손", "린트·타입체크도"
- 생성 코드까지 열어 숨은 매핑 경로 확인 (두 번 다) ← 비슷한 동작 코드와 차이 전부 나열하기
- 화면 요구 미충족을 결과서 첫머리에 밝힘 ← 요구 항목별 체크리스트, 완료 상태 명시
- 전체 오류 메시지 읽기, 재현 먼저, 모르면 모른다고 하기, 작은 단위로 수정, 커밋 전 전체 스위트 1회

**C. 사람 단계(3.3·3.4) 또는 native 기능이 이미 덮음**
- 최종 트리에서 다시 검증 ← 3.4에서 사람이 테스트를 재실행해 숫자를 대조한다 (두 번 다 일치)
- 변경 전 테스트 기준선 확보 ← 2장 Profile 작성 때 실제 실행 결과(183)가 기록되고, 3.4에서 그것과 대조한다
- 파괴적 명령(rm -rf, reset --hard, force-push, DROP) 전 확인 ← `settings.core.json`은 읽기 전용 git만 허용하므로 그 외 셸 명령은 Claude Code가 기본으로 사람에게 묻는다. 규칙을 다시 쓸 이유 없음
- agent 자체 코드 리뷰 ← Claude Code 내장 `/code-review` (조사 결론 4.3 "`/review`는 기본 기능과 겹침"). H1 참조
- 문서 갱신 누락 점검 ← 하네스 저장소 자체 규율. 배포 대상 프로젝트 규칙으로 일반화할 근거 없음

**D. 특정 환경·상황에서만**
- 비동기 테스트의 sleep → 조건 대기, 타임아웃 늘리지 않기 / 원인 못 찾은 경우의 로깅·재시도 추가 / 모든 계층에 검증 추가(defense in depth — 범위 규칙과 충돌) / 오류 검색 전 식별자 제거(웹 조회 허용 환경에서만) / 프레임워크별 콘솔 신호(hydration 등) / 권한 경계 확인 / 네트워크 실패 요청(현 `playwright-cli` 명령 목록에 없음) / 스파이크 결과물은 폐기 전제 / 스크린샷을 Read로 실제 보기(행동이 아니라 도구 함정 — 첫 FE 실행에서 걸리면 도구 줄에 적을 사실)

**E. 제품 구조·오케스트레이션·파이프라인 — 행동이 아님**
- Superpowers: skill 강제 호출 hook, 서브에이전트 분배·리뷰 루프·brief/report, worktree, 계획 파일 서식, 한 번에 질문 하나(상호작용 양식), 말투 규칙, skill 작성법
- gstack: browse daemon·CDP·쿠키, Review Army·fingerprint·hit-rate, Codex 교차 리뷰, gbrain/learnings, freeze/scope lock hook, health 점수, design-review 심미 규칙, ship/PR/VERSION/CHANGELOG, 질문 튜닝

---

## 5. 다음 관찰 포인트

새 실험을 설계하지 않는다. 이미 예정된 사용에서 어느 상황이 어느 후보를 확인하는지만 잇는다.

| 예정된 사용 (`harness-v0.md` 7.7·8.6) | 자연스럽게 확인되는 후보 | 보는 것 |
|---|---|---|
| 다음 B 실행 중 사람이 위임형 승인을 할 때 | **K1** | 결과서만으로 구현 중 판단을 전부 알 수 있는가 |
| 시나리오 C 첫 실행 (후보 입력: 10-05가 남긴 `POST /api/visits` 400 결함, 또는 fixture FE 복구) | **K2, K3**, H4 | 재현 테스트의 선실패를 보이는가. 수정이 한 번에 안 될 때 몇 번째에 멈추는가 |
| FE가 도는 저장소에서 첫 UI 변경 (7.7 #1) | **K4**, H5 | 보고가 "열어 확인"에서 멈추는가, 상호작용·콘솔까지 가는가. 스크린샷 Read 함정이 걸리는가 |
| 실제 고객 stack에서 DB·공유 계약을 건드리는 첫 CR | H3 | 마이그레이션·호환·되돌리기가 분석서에 저절로 나오는가 |
| 사람 리뷰가 결함을 놓친 첫 사례 | H1, H2 | 내장 `/code-review`로 잡혔을 것인가 |
| 시나리오 A 첫 실행 | H6 | 입력 크기에 따라 분해를 제안하는가 |

어느 후보든 **해당 상황에서 결손이 관찰되지 않으면 DROP으로 내린다.** 사용자 수준 Superpowers·gstack이 꺼진 환경에서 관찰되면 Core만의 증거가 되고, 켜진 환경이면 지금까지와 같은 단서를 붙인다.
