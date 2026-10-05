# Local AI Development Harness (v0.1.0)

> 상태: v0.1.0 동결 (2026-10-05). 사람이 직접 수행한 UAT 기록은 `docs/e2e-2026-10-05/README.md`.

개발자 PC에서 coding agent로 Frontend + Backend 코드를 찾고, 고치고, 실행하고, 브라우저로 확인하고, 테스트까지 끝내기 위한 최소 구성이다. 기본 agent는 Claude Code이고, 모델 접근 경로(직결 / Amazon Bedrock / 사내 게이트웨이)는 설정 교체로 바꾼다.

처음 써 보는 개발자는 `DEVELOPER-WALKTHROUGH.md`를 따라 한다. 설계 배경은 `docs/harness-v0.md`, 조사 근거는 `docs/research-result-claude.md`에 있다. 문서에서 언급하는 `docs/research.md`(조사 지시서와 검토 대화 원문)는 이 저장소에 포함하지 않는다.

## Quickstart

Windows PowerShell에서 실행한다. 스크립트 실행이 막혀 있으면 `powershell -ExecutionPolicy Bypass -File .\setup.ps1`처럼 실행한다.

**1. PC 준비**

```powershell
.\setup.ps1            # 무엇이 없는지 보고만 한다
.\setup.ps1 -Install   # 없는 것만 설치한다 (있는 것은 건드리지 않는다)
```

**2. 내 프로젝트에 붙이기**

```powershell
.\init-project.ps1 -ProjectPath C:\work\my-app
```

대상 저장소에 `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`이 생긴다. 이미 있는 파일은 하네스가 관리하는 부분만 바꾸고 나머지는 그대로 둔다.

**3. 신뢰 승인과 프로젝트 사실 채우기**

```powershell
cd C:\work\my-app
claude
```

처음 한 번은 폴더 신뢰 여부를 묻는다. 승인해야 권한 허용 규칙이 적용된다. 그 다음 `profiles/_template/fill-profile.prompt.md`를 열어 내용 전체를 세션에 붙여 넣어 agent가 `AGENTS.md`의 "프로젝트" 절(빌드·테스트·실행·화면 확인 방법)을 채우게 한다. 채워진 명령은 사람이 한 번씩 실제로 돌려 본다.

**4. 점검**

```powershell
C:\workspace\harness\check.ps1 -ProjectPath C:\work\my-app          # 모델 호출 없음
C:\workspace\harness\check.ps1 -ProjectPath C:\work\my-app -Live    # 모델에 짧은 요청 1회
```

`FAIL`이 없으면 개발을 시작한다.

## 모델 접근 경로 바꾸기

```powershell
.\init-project.ps1 -ProjectPath C:\work\my-app -Provider direct
.\init-project.ps1 -ProjectPath C:\work\my-app -Provider bedrock -AwsProfile <프로파일>
.\init-project.ps1 -ProjectPath C:\work\my-app -Provider gateway -GatewayUrl https://<승인된 게이트웨이>
```

| 경로 | 상태 |
|---|---|
| `direct` | 실제 호출까지 검증됨 |
| `bedrock` | 설정 구조와 전환까지만 검증됨. AWS 호출은 한 번도 하지 않았다. 서울 리전, 리전 내 모델 ID 고정 |
| `gateway` | 설정 구조만. 게이트웨이 주소가 필요하고, 자격증명은 저장소에 넣지 않는다 |

`check.ps1 -Live`는 `direct`가 아닌 경로에서는 `-AllowProviderCall`을 같이 줘야 호출한다. 점검 때문에 클라우드 계정에 실수로 과금되지 않게 하기 위해서다.

## 들어 있는 것

| 위치 | 내용 |
|---|---|
| `setup.ps1` | PC에 기본 agent와 능력 도구가 있는지 확인하고, `-Install`이면 없는 것만 설치 |
| `check.ps1` | PC와 프로젝트 상태 점검. `PASS` / `WARN` / `FAIL` |
| `init-project.ps1` | 대상 저장소에 프로젝트 층 적용. 다시 실행해도 안전 |
| `core/AGENTS.core.md` | 모든 프로젝트 공통 규칙 6줄 |
| `core/settings.core.json` | 권한 규칙: 읽기 전용 git 명령 허용, 비밀 파일 읽기 차단 |
| `core/providers/` | 모델 접근 경로별 설정 |
| `core/capabilities.json` | 능력별로 채택한 구현 하나와 선택 이유 |
| `core/policy/managed-settings.example.json` | 조직 정책 템플릿 (적용하지 않음) |
| `profiles/_template/` | 프로젝트 사실을 채우는 빈 틀, `verify-change` skill 템플릿 |

능력별 구현:

| 능력 | 구현 | 설치 |
|---|---|---|
| 화면 확인 | Playwright CLI로 PC에 설치된 Edge를 구동 | npm 패키지 하나. 브라우저 다운로드 없음 |
| 문서 조회 | 설치된 버전의 로컬 소스·타입 정의·문서를 agent가 읽음 | 없음 |

## 들어 있지 않은 것

Hooks, MCP 서버, 프로젝트 무관 skill은 0개다. Superpowers, gstack, Context7, Orca는 기본 구성에 넣지 않는다. Serena와 CodeGraph는 보류이며 대형 저장소에서 필요성이 드러나면 다시 본다. 현재 판정과 향후 확장 후보(DB 클라이언트, 문서 변환, runtime 관찰 등)는 `docs/harness-v0.md` 8장에 있다.

## 자주 걸리는 것

- **`Auth source` 경고**: 환경 변수 `ANTHROPIC_API_KEY` 등이 있으면 claude.ai 로그인보다 우선한다. 의도한 것이 아니면 환경 변수를 지운다.
- **`Workspace trust` 경고**: 프로젝트 폴더에서 `claude`를 한 번 실행해 신뢰를 승인한다.
- **`Project facts` 경고**: `AGENTS.md`의 명령 표가 비어 있다. 3단계를 한다.
- **화면 확인이 `file:` 주소에서 막힘**: 앱을 띄워 http 주소로 연다.

## 알려진 한계

- 비밀 파일 차단은 agent의 파일 읽기 도구 기준으로 확인했다. 셸 명령으로 우회하는 경우는 확인하지 않았다. Windows 네이티브에서는 Claude Code의 샌드박스가 지원되지 않는다.
- 조직 정책 템플릿은 예시이고 실제 PC에 적용해 검증하지 않았다.
- Codex CLI와 OpenCode는 `AGENTS.md`를 함께 읽는 것 외에 별도 설정을 만들지 않는다.
