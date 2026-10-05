# CR-001 구현 결과 (Backend 범위)

- 근거: `CR-001-analysis.md` + 사람 결정 (F1, D1~D5, D7)
- 작업일: 2026-10-04
- 범위: Backend만. Frontend 코드는 바꾸지 않았다(F1). 커밋은 하지 않았다.

## 적용한 결정

| 결정 | 구현 |
|---|---|
| D1 | `today-30 <= 방문일 <= today`이면 최근 방문. 30일 전은 포함, 31일 전은 제외. 일수는 `VisitRecencyPolicy.RECENT_DAYS = 30` |
| D2 | `Clock` 빈을 `Asia/Seoul`로 고정 (`ClockConfig.CLINIC_ZONE`) |
| D3 | 미래 날짜는 false |
| D4 | 필드명 `recentVisit` (boolean, readOnly) |
| D5 (B2) | `PetMapper`에 중첩 visits 전용 매핑을 따로 두고 `petId`는 `ignore`. owner·pet API의 중첩 visits `petId`는 계속 null이다. 새 필드만 추가했다 |
| D7 | `Clock` 빈과 설정 클래스 1개(`ClockConfig`)만 추가했다. 의존성은 추가하지 않았다 |
| (분석 가정) | 날짜 없는 방문은 false, 예외 없음 |

## 변경 파일

| 파일 | 내용 |
|---|---|
| `src/main/resources/openapi.yml` | `Visit` 스키마에 `recentVisit`(boolean, readOnly, 기준 설명 포함) 추가. `VisitFields`(요청 바디)는 그대로 |
| `src/main/java/.../config/ClockConfig.java` (신규) | `Clock.system(Asia/Seoul)` 빈 |
| `src/main/java/.../service/VisitRecencyPolicy.java` (신규) | 판정 로직 `isRecent(LocalDate)`, `@Named("isRecentVisit")` |
| `src/main/java/.../mapper/VisitMapper.java` | `uses`에 `VisitRecencyPolicy` 추가, `toVisitDto`에 `recentVisit` 매핑 |
| `src/main/java/.../mapper/PetMapper.java` | `uses = VisitRecencyPolicy.class`. 중첩 visits용 `toVisitDto`(`@Named("toNestedVisitDto")`, `petId` ignore, `recentVisit` 매핑)와 `toNestedVisitDtos`(`@IterableMapping`)를 선언하고 `toPetDto`의 `visits`가 이를 쓰게 했다. `@Named`를 붙인 이유: 이름 없이 두면 `VisitMapper`가 `PetMapper`를 `uses`하고 있어 컬렉션 매핑 시 "Ambiguous mapping methods" 컴파일 오류가 난다 |
| `src/test/java/.../service/VisitRecencyPolicyTests.java` (신규) | 단위 테스트 8개 |
| `src/test/java/.../rest/controller/VisitRestControllerTests.java` | 테스트 1개 추가 |
| `src/test/java/.../rest/controller/OwnerRestControllerTests.java` | 테스트 1개 추가 |

## 추가한 테스트

**`VisitRecencyPolicyTests`** (`Clock.fixed` = 2026-10-04 00:00 KST)
- `todayIsRecent`: 오늘 → true
- `yesterdayIsRecent`: 어제 → true
- `exactly30DaysAgoIsRecent`: 30일 전 → true
- `exactly31DaysAgoIsNotRecent`: 31일 전 → false
- `futureDateIsNotRecent`: 내일 → false
- `missingDateIsNotRecent`: null → false
- `todayIsTakenInAsiaSeoulNotUtc`: 같은 시각에 UTC 기준 날짜가 아니라 Seoul 기준 날짜로 판정되는지
- `monthEndAndLeapYear`: 2028-03-01 기준으로 2028-01-31은 true, 2028-01-30은 false

**컨트롤러 테스트** (오늘 날짜는 주입된 `Clock` 빈으로 계산)
- `VisitRestControllerTests#testGetVisitsRecentVisitFlag`: `GET /api/visits/2`가 30일 전 방문에 대해 `recentVisit=true`이고 `petId=8`인지, `GET /api/visits`에서 30일 전은 true, 31일 전은 false인지 확인
- `OwnerRestControllerTests#testGetOwnerNestedVisitsHaveRecentVisitFlag`: `GET /api/owners/1`의 `pets[0].visits`에서 30일 전은 true, 31일 전은 false인지, 그리고 중첩 visit의 `petId`가 null로 유지되는지(D5) 확인

## 실행한 검증과 결과

1. `.\mvnw.cmd -B test`: **BUILD SUCCESS, 193개 통과** (기존 183 + 신규 10, 실패·에러 0). 서비스 테스트 3개 프로필(Jdbc/Jpa/SpringDataJpa)과 `SpringConfigTests`의 컨텍스트 로딩도 통과했다.
2. `.\mvnw.cmd spring-boot:run`으로 서버를 띄운 뒤(기본 프로필, 9966 포트) curl 대신 PowerShell `Invoke-WebRequest`로 다음을 확인했다.
   - `POST /petclinic/api/owners/6/pets/7/visits`로 방문 3건 등록 → 모두 201
     - 2026-10-04(오늘): `"petId":7,"recentVisit":true`
     - 2026-09-04(30일 전): `"recentVisit":true`
     - 2026-09-03(31일 전): `"recentVisit":false`
   - `GET /petclinic/api/owners/6`: pet 7의 중첩 visits에서 위 3건이 각각 true/true/false, 2013년 기존 방문은 false. 중첩 visits의 `petId`는 기존과 같이 모두 null
   - `GET /petclinic/api/visits`: 모든 항목에 `recentVisit`이 들어 있고 `petId`는 기존과 같이 채워져 있음
   - 서버 종료: 프로세스 트리를 종료하고 9966 포트가 닫힌 것을 확인했다.

## 확인하지 못한 것 (미확인)

- **Frontend 화면**(R1 배지, R2 상세 보기, 인수 기준 1·3의 화면 확인): F1 결정에 따라 구현하지 않았고 확인하지 않았다. 별도 CR로 넘긴다.
- **Swagger UI**에 `recentVisit` 필드와 설명이 보이는지는 열어 보지 않았다(분석 6.3절 4번).
- `GET /api/pets/{id}`, `GET /api/owners/{o}/pets/{p}` 응답: 같은 `PetMapper#toPetDto` 경로라 값이 실릴 것으로 보지만, 전용 테스트를 추가하지 않았고 실행해서 확인하지도 않았다[추정].
- 미래 날짜와 날짜 없는 방문은 단위 테스트로만 확인했다. 서버에서 실제로 등록해 보지는 않았다.
- `.\mvnw.cmd -B package`/`install`과 JaCoCo `verify` 커버리지 기준은 실행하지 않았다.
- 운영 서버 시간대는 여전히 모른다. `Clock`을 Asia/Seoul로 고정했으므로 판정은 서버 시간대와 무관하지만, 기존 코드의 `LocalDate.now()`(예: `Visit` 생성자 기본값)는 계속 JVM 기본 시간대를 따른다(이번 범위 밖).
