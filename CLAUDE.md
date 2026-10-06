# Harness 프로젝트 (이 폴더 자체가 제품)

고객사(대형 유통사) 협력사의 FE+BE 개발자 PC에 배포할 Local AI Development Harness 원형. 기본 agent Claude Code, 호환 Codex CLI·OpenCode. 모델 경로는 직결/Bedrock/게이트웨이를 설정 교체로 바꾼다.

## 먼저 읽을 것

1. `docs/harness-v0.md` **8장** — 현재 판단(동결, 판정, 확장 원칙, 확장 후보 inventory). 앞 장들은 당시 기록이고 다르면 8장을 따른다
2. `docs/e2e-2026-10-05/README.md` — 사람이 직접 수행한 UAT 기록 (전날 자동 E2E는 `docs/e2e-2026-10-04/`)
3. `DEVELOPER-WALKTHROUGH.md` — 사람이 직접 따라 하는 UAT

배경: `docs/research-result-claude.md`(조사 결론), `docs/research.md`(지시서 + GPT 교차검토 대화 원문, 끝에 최신 GPT 의견이 붙는다. 로컬 전용이며 공개 저장소에는 올리지 않는다).

## 현황 (2026-10-05 종료 시점)

- **v0.1.0 동결.** 지금 추가할 항목 없음. v0.1.1을 만들 근거가 확인되지 않았다
- 판정: Superpowers·gstack·Context7·Orca는 기본 구성에서 제외. Serena·CodeGraph·Skills·Hooks·MCP는 보류(Skills는 슬롯과 템플릿만, Hooks·MCP는 0개)
- 검증: 자동 E2E 1회 + Human UAT 1회(petclinic, 시나리오 B, Backend 범위). 관찰표 7/8 PASS, 화면 확인은 판정 불가
- 두 실행 모두 세션에 사용자 수준 Superpowers·gstack·전역 CLAUDE.md가 적용돼 있었다. **Core만의 증거라고 쓰지 않는다. 무효로 보지도 않는다**
- 미확인: 실제 앱 브라우저 확인, 시나리오 A·C, 업무급 저장소와 실제 고객 stack, Bedrock·게이트웨이 실제 호출

## 다음에 무엇을 할지

정해진 다음 작업은 없다. 사용자가 지시하기 전에 새 조사·실험·설치·구현을 시작하지 않는다. 확장을 논의하게 되면 `docs/harness-v0.md` 8.4(작업 원칙)와 8.5(확장 후보 inventory)에서 출발한다. 요지는 "모델에게 절차를 더 주입하기보다, 저장소 밖에 있어 모델이 못 보는 실제 개발 자원(DB, 문서, runtime, 개발 이력 등)을 열어 주는 것을 먼저 본다"이다. Oracle 환경이면 SQLcl이 우선 후보다.

**2026-10-06 추가 — 재개 트리거.** Superpowers·gstack을 행동 단위로 재검토한 결과(`docs/review-2026-10-06-residual-capabilities.md`: 약 70개 → KEEP-CANDIDATE 4, HOLD 6, 지금 추가 0) 억지로 돌릴 시나리오가 없다고 판단했다. 아래 셋 중 하나가 생기기 전까지 하네스 작업을 열지 않는다.

| 트리거 | 그때 보는 것 |
|---|---|
| 업무급 Java 저장소가 붙음 | Serena·CodeGraph profile 비교(`harness-v0.md` 7.7 #3), 같은 저장소에서 FE 브라우저 확인 첫 실측(7.7 #1), 검토 문서의 K1~K4 자연 관찰 |
| 개발 DB 접근이 열림 | SQLcl(8.5 #1) |
| 배포 규칙·대상이 식별됨 | 배포 전 반드시 닫을 빈칸 = 브라우저 확인은 실제 FE 저장소에서 한 번도 검증되지 않았다 |

시나리오를 실제로 돌릴 때는 그 PowerShell 창에서 `$env:CLAUDE_CONFIG_DIR = <빈 폴더>`로 사용자 수준 플러그인·skill·전역 지침을 뺀다(10-06 확인: 빈 config dir → 플러그인 0개). 그래야 "모델이 알아서 했다 → DROP" 판정이 가능하다. 오염된 환경에서는 후보를 살릴 수만 있고 죽일 수 없다.

## 규율

- 지시받지 않은 개선·추가 구현 금지. 판정은 증거 기반, 미검증은 미검증으로 적는다
- 새 도구·제품은 후보 조사 → 선택 근거 → 하나 채택 순서. "유명해서" 추가 금지. 기존 도구가 해결하는 문제를 새 MCP·Skill·wrapper로 다시 만들지 않는다. native CLI가 충분하면 CLI 우선
- "시험하지 않았으니 필요 없다"고 쓰지 않는다. "관찰된 결손이 없어 추가할 근거가 없다"고 쓴다
- 사람 결정이 필요한 단계에서 권장안 일괄 수용을 검토로 간주하지 않는다
- 다른 프로젝트의 클라우드 계정(이 PC에 자격증명이 있는 AWS 계정 포함)은 이 하네스 검증에 쓰지 않는다
- 이 PC의 사용자 환경 변수 `ANTHROPIC_API_KEY`(크레딧 없음)가 구독 로그인을 덮어쓴다. 지우지 말고, agent 실행 시 해당 프로세스에서만 비운다(`$env:ANTHROPIC_API_KEY = $null`)
- 스크립트는 Windows PowerShell 5.1 호환, ASCII 전용
