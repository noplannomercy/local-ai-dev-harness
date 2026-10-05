# CR-001 분석: 재방문 관리 대상 진료기록 표시

- 대상 요청서: `docs/change-requests/CR-001.md`
- 분석일: 2026-10-04
- 범위: 분석만 했다. 소스·설정·테스트는 바꾸지 않았다.
- 표기: **[확인]** 코드를 읽었거나 실행해서 직접 확인함 / **[추정]** 코드로 추론했고 실행해 보지는 않음

### 확인 방법

- 코드 읽기: `client/src/**`, `openapi.yml`, `pom.xml`, 컨트롤러·매퍼·서비스·저장소·엔티티, 테스트 코드, 그리고 이전 빌드에서 생성된 `target/generated-sources/annotations/.../*MapperImpl.java`.
- Backend를 실행(`mvnw spring-boot:run`, 기본 프로필 `hsqldb,spring-data-jpa`)하고 curl로 API를 호출해 본 뒤 종료했다. 이때 호출한 것:
  - `GET /api/owners/6`, `GET /api/visits/1`
  - `POST /api/owners/6/pets/7/visits`. 인메모리 DB라 재기동하면 초기화된다.
  - `GET /petclinic//api/owners/6`
- 코드를 바꾸지 않았으므로 테스트는 다시 돌리지 않았다. 기준선은 AGENTS.md에 기록된 "183개 통과"다.

---

## 1. 요구 해석

### 1.1 이해한 내용

| # | 요구 | 해석 |
|---|---|---|
| R1 | 반려동물별 방문 목록에서 최근 30일 이내 방문에 "최근 방문" 표시 | 방문(Visit) 하나하나에 "최근 방문 여부"라는 성질이 있다. 화면은 이 값이 참일 때만 "최근 방문" 배지나 문구를 붙이고, 행 스타일로도 구분한다. |
| R2 | 방문을 하나 고르면 상세(방문일, 진료 내용 전체)가 보임 | 목록의 방문 행을 고를 수 있어야 하고, 고르면 방문일과 설명 전문이 보여야 한다. 줄바꿈과 긴 텍스트도 잘리지 않아야 한다. |
| R3 | 최근 여부는 서버가 판단해서 내려줌. 다른 화면·보고서도 같은 기준 사용 | API 응답의 Visit에 판정 결과(boolean)를 넣는다. 판정 로직은 매퍼나 컨트롤러 안에 묻지 말고, 다른 곳에서도 부를 수 있는 독립 컴포넌트 하나로 둔다. |
| 제약 | 등록·수정 기능 불변, 기존 API 소비자 보호, DB 스키마 불변 | 필드는 **추가만** 한다(기존 필드의 이름·타입·의미는 그대로). 판정 결과를 DB 컬럼에 저장하지 않고 조회할 때 계산한다. |

### 1.2 모호한 점과 가정

| 항목 | 모호한 점 | 가정 (권고) | 사람 결정 필요 |
|---|---|---|---|
| **30일 경계** | 요구 문구 "오늘을 포함해 최근 30일 이내"를 글자대로 읽으면 오늘부터 거꾸로 30개 날짜, 즉 `today-29 ~ today`다. 그런데 인수 기준은 "정확히 30일 전, 31일 전"을 경계로 들고 있어서 `today-30`은 포함, `today-31`은 제외로 읽힌다(`today-30 ~ today`, 31개 날짜). 두 읽기가 **하루 차이로 충돌**한다. | 인수 기준 쪽을 따른다: `today.minusDays(30) <= visitDate <= today`. 30일 전은 "최근 방문", 31일 전은 아니다. 일수는 상수 하나로 두어 결정이 바뀌면 한 곳만 고치게 한다. | **예.** 운영팀에 "30일 전 방문이 최근 방문인가"를 확인해야 한다. |
| **기준 시각** | "오늘"이 언제 정해지는지 | 응답을 만드는 순간 서버 시계로 계산한 **날짜(LocalDate)**를 쓴다. 방문일이 `DATE` 컬럼이고 시각이 없으므로 날짜끼리만 비교한다. | 아니오 |
| **시간대** | 서버 JVM 기본 시간대에 맡길지 | 현재 실행 환경은 `Korea Standard Time`이다[확인]. 다만 저장소 어디에도 시간대 설정이 없다[확인]. 배포 서버가 UTC면 한국 시각 00:00~09:00 사이에는 "오늘"이 하루 늦어진다. `Clock` 빈을 `Asia/Seoul`로 고정하기를 권고한다(대안: JVM 기본값 사용). | **예.** 운영 서버 시간대와 기준 시간대(KST로 고정할지) |
| **미래 날짜 방문** | 방문일에 검증이 없어 미래 날짜를 넣을 수 있다. 스키마 설명도 "A booking for a vet visit"이다. | "다녀간" 기록이 아니므로 **최근 방문 아님(false)**. 조건이 `visitDate <= today`다. | **예.** 예약을 "최근 방문"으로 볼지 |
| **날짜 없는 방문** | `POST .../visits`에 `date`를 빼고 보내면 `date=null`로 저장된다[확인: 응답 `{"date":null,...}`]. 엔티티 생성자의 `LocalDate.now()` 기본값을 MapStruct가 null로 덮어쓴다. | `false`로 판정하고 예외를 던지지 않는다. | 아니오 |
| **API 필드명·형태** | 정해진 것이 없다. | `Visit` 스키마에 `recentVisit: boolean`(readOnly)을 추가한다. 위치는 `VisitFields`가 아니라 `Visit` 쪽이다. 그래야 요청 DTO(`VisitFieldsDto`)는 바뀌지 않는다. | 이름만 확인 |
| **상세 보기 형태** | 별도 페이지인지, 같은 화면에서 펼치는지 | 같은 화면에서 행을 고르면 아래에 상세 패널이 보이는 방식. 근거는 5.3절 참고. | **예.** 화면 형태 |
| **"잘려 보이는 경우"** | 현재 목록에 말줄임 CSS는 없다[확인: `PetsTable.tsx`에 스타일 없음]. 다만 HTML이 줄바꿈을 무시해서 여러 줄 설명이 한 줄로 보인다. | 상세 패널은 `white-space: pre-wrap`으로 줄바꿈을 살려 전문을 보여준다. 목록은 그대로 둔다(표시 방식 변경은 요구 밖). | 아니오 |

---

## 2. 현재 흐름 (방문 기록이 화면에 보이기까지)

### 2.1 경로

```
[화면] /owners/:ownerId  (configureRoutes.tsx → OwnersPage)
  OwnersPage.componentDidMount()
    fetch(url(`/api/owner/${ownerId}`))          ← 단수 'owner'
  → render: <OwnerInformation/> + <PetsTable owner/>
       PetsTable → (내부) VisitsTable: pet.visits.map → <td>{visit.date}</td><td>{visit.description}</td>
                                                              ↓ HTTP
[API]  GET /petclinic/api/owners/{ownerId}   (openapi.yml: operationId getOwner, 응답 Owner → pets[] → visits[] : Visit)
  생성 인터페이스 rest.api.OwnersApi#getOwner (target/generated-sources/openapi)
[컨트롤러] rest/controller/OwnerRestController#getOwner(Integer)
  → clinicService.findOwnerById(ownerId)
  → ownerMapper.toOwnerDto(owner)
       OwnerMapperImpl → petMapper.toPetDto(pet)
            PetMapperImpl → visitListToVisitDtoList → visitToVisitDto   ← VisitMapper가 아니라 PetMapper가 자체 생성한 메서드
[서비스] service/ClinicServiceImpl#findOwnerById(int)  (@Transactional(readOnly=true))
  → ownerRepository.findById(id)
[저장소] (기본 프로필 spring-data-jpa) repository/springdatajpa/SpringDataOwnerRepository#findById
           @Query "SELECT owner FROM Owner owner left join fetch owner.pets WHERE owner.id =:id"
         (jpa)  repository/jpa/JpaOwnerRepositoryImpl#findById  (같은 JPQL)
         (jdbc) repository/jdbc/JdbcOwnerRepositoryImpl#findById → loadPetsAndVisits → JdbcPetVisitExtractor
[엔티티] model/Owner → model/Pet.visits (@OneToMany(mappedBy="pet", fetch=EAGER))
           Pet#getVisits(): date 내림차순으로 정렬한 불변 List
         model/Visit (date: LocalDate @Column visit_date DATE, description, pet)
[DB]     visits(id, pet_id, visit_date DATE, description)  — db/hsqldb/initDB.sql
```

### 2.2 확인 상태

| 구간 | 상태 | 근거 |
|---|---|---|
| 라우트 `/owners/:ownerId` → `OwnersPage` | [확인] 코드 | `client/src/configureRoutes.tsx:31` |
| `OwnersPage`가 `/api/owner/{id}`(단수)를 호출 | [확인] 코드 | `client/src/components/owners/OwnersPage.tsx:30` |
| 이 호출은 지금 실패한다 | [확인] 실행. 단수 경로는 Backend에 없음(AGENTS.md: 400). `url('/api/...')`는 `//api`가 되어 400을 확인했다. | `util/index.tsx:6`의 `${BACKEND_URL}/${path}` |
| 방문 목록 렌더링 `VisitsTable` | [확인] 코드 | `client/src/components/owners/PetsTable.tsx:6-31` |
| `GET /api/owners/{id}` 응답에 visits가 중첩됨 | [확인] 실행. `GET /api/owners/6` 응답의 `pets[].visits[]`에 date, description, id, petId가 있다. | |
| **중첩 visits의 `petId`는 항상 null** | [확인] 실행: `"petId":null`. 반면 `GET /api/visits/1`은 `"petId":7`이다. | `PetMapper`에 `uses=VisitMapper`가 없어서 MapStruct가 `PetMapperImpl#visitToVisitDto`를 따로 생성했고, 거기에 `@Mapping(source="pet.id", target="petId")`이 빠져 있다. |
| 컨트롤러 → 서비스 → 저장소 호출 | [확인] 코드 | `OwnerRestController.java:87-93`, `ClinicServiceImpl.java:225` |
| 기본 프로필에서 실제로 쓰는 저장소 구현은 springdatajpa | [확인] 코드(`application.properties`). 실제 동작한 빈은 [추정] | |
| Pet.visits EAGER 로딩, 날짜 내림차순 정렬 | [확인] 코드 | `model/Pet.java:48-49, 87-91` |
| 초기 데이터의 방문은 모두 2013년이라 "최근 방문"이 하나도 없음 | [확인] 코드 | `db/hsqldb/populateDB.sql:50-53` |

### 2.3 같은 Visit 데이터가 나가는 다른 경로

| API | 컨트롤러 | 매핑 경로 |
|---|---|---|
| `GET /api/owners`, `GET /api/owners/{id}` | `OwnerRestController#listOwners/getOwner` | OwnerMapper → PetMapper → `PetMapperImpl#visitToVisitDto` |
| `GET /api/owners/{o}/pets/{p}`, `POST /api/owners/{o}/pets` | `OwnerRestController#getOwnersPet/addPetToOwner` | `petMapper.toPetDto` → 같은 경로 |
| `GET /api/pets`, `GET /api/pets/{id}`, `PUT /api/pets/{id}` | `PetRestController` | `petMapper.toPetDto(s)` → 같은 경로 |
| `GET /api/visits`, `GET/PUT/DELETE /api/visits/{id}`, `POST /api/visits` | `VisitRestController` | `VisitMapper#toVisitDto(s)` |
| `POST /api/owners/{o}/pets/{p}/visits` | `OwnerRestController#addVisitToOwner` | `VisitMapper#toVisitDto` (응답 201) |

**결론**: Visit DTO는 MapStruct 생성 메서드 **두 벌**(`VisitMapperImpl#toVisitDto`, `PetMapperImpl#visitToVisitDto`)로 만들어진다. 새 필드를 한쪽에만 넣으면, 반려동물별 목록 화면이 쓰는 owner API에서 값이 빠진다.

---

## 3. 영향 범위

### 3.1 바꿔야 하는 곳

| 파일 | 변경 | 이유 |
|---|---|---|
| `src/main/resources/openapi.yml` | `components.schemas.Visit`의 두 번째 `allOf` 객체에 `recentVisit`(boolean, readOnly, 설명에 기준 명시) 추가 | API 계약이 원본이다. `VisitDto`에 필드가 생성된다. `VisitFields`는 그대로 두므로 `VisitFieldsDto`(방문 등록 요청 바디)는 바뀌지 않는다. |
| 신규 `service/VisitRecencyPolicy.java`(이름 가칭) | `boolean isRecent(LocalDate visitDate)` + 상수 `RECENT_DAYS = 30`. 생성자로 `Clock`을 주입받는다. | R3에 따라 단일 기준이 필요하다. 테스트에서 오늘 날짜를 고정하려면 `Clock` 주입이 필수다. |
| 신규 `Clock` 빈 정의 (예: `config/ClockConfig.java` 또는 기존 설정 클래스) | `Clock.system(ZoneId.of("Asia/Seoul"))` 또는 `Clock.systemDefaultZone()` | 저장소에 `Clock` 빈이 없다[확인: `grep Clock` 결과 0건]. 시간대 결정(1.2절)에 따라 고른다. |
| `mapper/VisitMapper.java` | `uses`에 `VisitRecencyPolicy` 추가, `toVisitDto`에 `@Mapping(target="recentVisit", source="date", qualifiedByName=...)` | `/api/visits*` 응답과 방문 등록 응답에 값을 채운다. |
| `mapper/PetMapper.java` | `@Mapper(uses = VisitMapper.class)` 추가(권고). 대안은 아래 5.2절 | owner·pet API의 중첩 visits도 `VisitMapper#toVisitDto`를 타게 해서 한 벌로 합친다. |
| `client/src/types/index.ts` | `IVisit`에 `recentVisit?: boolean` 추가 | 타입 정의 |
| `client/src/components/owners/PetsTable.tsx` | `VisitsTable`에 "최근 방문" 표시, 행 선택 상태, 상세 패널 | R1·R2 |
| (선택) 신규 `client/src/components/visits/VisitDetails.tsx` | 상세 표시 컴포넌트 | `visits/PetDetails.tsx`와 같은 형태의 무상태 컴포넌트 |

### 3.2 바꾸지 않는 곳 (그리고 그 이유)

- **DB 스키마·초기 데이터**: 판정 결과는 계산값이므로 컬럼이 필요 없다. 제약 조건과 맞는다.
- **저장소 3벌(jdbc/jpa/springdatajpa)**: 조회 쿼리를 바꿀 필요가 없다. 날짜 비교는 매핑 단계에서 한다. 그래서 "3벌을 함께 맞춘다"는 규칙에 해당하지 않는다.
- **엔티티 `Visit`**: 필드를 추가하지 않는다(`@Transient`도 쓰지 않음). 대안 검토는 5.2절.
- **방문 등록 화면 `VisitsPage.tsx`, 보호자·반려동물 등록/수정 화면**: 제약 조건에 따라 건드리지 않는다.

### 3.3 같은 API·DTO·엔티티를 쓰는 다른 곳과 깨질 가능성

| 대상 | 영향 | 깨질 가능성 |
|---|---|---|
| owner/pet/visit 조회 API 응답 | 필드 하나가 **추가**된다. 기존 필드는 그대로다. | 낮음. 단, 알 수 없는 필드를 거부하는 엄격한 클라이언트가 있다면 영향이 있다(저장소 안에는 없음). |
| `POST /api/visits`, `PUT /api/visits/{id}`의 요청 바디(`VisitDto`) | `recentVisit`을 보내도 무시된다. `Visit` 엔티티에 대상 필드가 없어서 MapStruct가 매핑하지 않는다[추정]. | 낮음 |
| `OwnerMapper#toOwner(OwnerDto)`, `PetMapper#toPet(PetDto)`의 역방향 매핑 | 역방향 `VisitDto→Visit`에서 `recentVisit`은 버려진다[추정]. | 낮음 |
| **`PetMapper`가 `VisitMapper`를 쓰게 바꾸는 경우의 부수효과** | owner·pet API의 중첩 visits에서 지금 항상 `null`인 `petId`에 값이 채워진다. | 버그 수정이지만 **기존 응답 값이 바뀐다**. 의도하지 않은 변경으로 볼 수 있으니 결정이 필요하다(7절). |
| 매퍼 빈 순환 의존 | `VisitMapper`는 `uses = PetMapper.class`로 선언돼 있지만, 생성된 `VisitMapperImpl`은 PetMapper를 주입받지 않는다[확인]. 따라서 `PetMapper → VisitMapper` 의존만 생기고 순환은 없다[추정]. 빌드한 뒤 확인해야 한다. | 중간. 순환 참조가 생기면 Spring Boot 3에서 기동이 실패한다. |
| MapStruct `unmappedTargetPolicy` | 기본값 WARN이고 `pom.xml`에 따로 설정한 것이 없다[확인]. 매핑이 빠져도 빌드는 통과하므로 **빠뜨려도 조용히 null이 나간다**. | 테스트로 막아야 한다. |
| 기존 백엔드 테스트 | 응답 JSON 전체를 비교하는 테스트는 찾지 못했다(`jsonPath`로 개별 필드만 확인)[확인: grep]. 컨트롤러 테스트는 `ApplicationTestConfig` 컨텍스트에서 매퍼를 `@Autowired`로 받으므로, `Clock` 빈과 `VisitRecencyPolicy` 빈이 테스트 컨텍스트에도 등록돼야 한다. | 중간. 빈이 빠지면 컨텍스트 로딩 실패로 모든 컨트롤러 테스트가 깨진다. |
| 서비스 테스트(`ClinicService*Tests`) | 매퍼를 거치지 않는다. | 없음[추정] |
| ETag 헤더(OpenAPI 정의) | 응답 바디가 날짜에 따라 바뀌므로 ETag도 날이 바뀌면 달라진다. | 영향 없음. 오히려 맞는 동작이다. |
| Frontend 다른 화면 | `IVisit`을 쓰는 곳은 `PetsTable.tsx`와 `VisitsPage.tsx`뿐이다[확인: grep]. 선택 필드(`?`)로 추가하면 영향이 없다. | 낮음 |

---

## 4. 따라야 할 기존 패턴

| 영역 | 이 저장소의 방식 | 근거 |
|---|---|---|
| API 정의 | `openapi.yml`을 먼저 고친다. 스키마는 `XxxFields`(편집 가능 필드)와 `Xxx`(`allOf` + `id` 같은 `readOnly` 필드)로 나뉜다. 서버가 계산하는 값은 `Xxx` 쪽에 `readOnly: true`로 둔다(예: `Pet.ownerId`, `Visit.petId`). | `openapi.yml:2100-2144`, `2015-2048` |
| 코드 생성 | openapi-generator `spring`, `interfaceOnly=true`, `modelNameSuffix=Dto`, `dateLibrary=java8`, `openApiNullable=false`. 생성 파일은 직접 고치지 않는다. | `pom.xml:267-287` |
| 컨트롤러 | 생성 인터페이스(`OwnersApi`, `VisitsApi` 등)를 구현한다. 메서드마다 `@PreAuthorize("hasRole(@roles.OWNER_ADMIN)")`를 붙인다. 엔티티를 받으면 매퍼로 DTO를 만든다. 계산 로직은 넣지 않는다. | `VisitRestController.java`, `OwnerRestController.java` |
| DTO 매핑 | MapStruct 인터페이스, `defaultComponentModel=spring`, 다른 매퍼는 `uses`로 참조, 파생 필드는 `@Mapping(source="pet.id", target="petId")`처럼 표현한다. | `mapper/VisitMapper.java:14-21`, `pom.xml:336` |
| 컨트롤러 테스트 | `@SpringBootTest` + `@ContextConfiguration(classes=ApplicationTestConfig.class)` + `@WebAppConfiguration`. `@MockBean ClinicService`를 쓰고 매퍼는 실제 빈을 `@Autowired`로 받는다. `MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(new ExceptionControllerAdvice())`로 MockMvc를 만들고, `@WithMockUser(roles="OWNER_ADMIN")` 아래에서 `jsonPath`로 검증한다. 테스트 데이터의 날짜는 `LocalDate.now()`로 만든다. | `VisitRestControllerTests.java`, `OwnerRestControllerTests.java` |
| 단위 테스트 | Spring 없이 JUnit 5만 쓴다(예: `model/ValidatorTests.java`). | |
| Frontend 컴포넌트 | 데이터를 받는 페이지는 클래스 컴포넌트에 `state`를 둔다. 표시만 하는 부분은 화살표 함수형 무상태 컴포넌트다(`PetsTable`, `PetDetails`). Bootstrap 클래스(`table`, `table-striped`, `dl-horizontal`)를 쓴다. React 15 / TS 2.0 문법이다. | `components/owners/*.tsx`, `components/visits/PetDetails.tsx` |

---

## 5. 수정 계획

### 5.1 순서 (파일 단위)

**Backend** (단계마다 `.\mvnw.cmd -B test` 실행)

1. `src/main/resources/openapi.yml`: `Visit` 스키마에 `recentVisit` 추가(boolean, readOnly). 설명은 "방문일이 서버 기준 오늘로부터 30일 전 ~ 오늘 사이이면 true. 미래 날짜와 날짜 없음은 false"로 쓰되, 확정된 기준으로 문구를 맞춘다. 빌드해서 `VisitDto#getRecentVisit`이 생성되는지 확인한다.
2. `Clock` 빈 추가: 신규 설정 클래스 1개. 테스트 컨텍스트에서 이 빈이 잡히는지도 확인한다(`ApplicationTestConfig`는 빈 껍데기이고 `@SpringBootTest`라 메인 설정을 스캔한다[추정]).
3. 신규 `service/VisitRecencyPolicy.java` (`@Component`):
   - `isRecent(LocalDate date)`: `date != null && !date.isAfter(today) && !date.isBefore(today.minusDays(RECENT_DAYS))`, `today = LocalDate.now(clock)`
   - MapStruct에서 부를 수 있게 `@Named("isRecentVisit")`을 붙인다.
4. 신규 `VisitRecencyPolicyTests.java`: 순수 단위 테스트. `Clock.fixed`를 쓴다(6.1절).
5. `mapper/VisitMapper.java`: `uses = {PetMapper.class, VisitRecencyPolicy.class}`로 바꾸고, `toVisitDto`에 `@Mapping(target="recentVisit", source="date", qualifiedByName="isRecentVisit")`를 추가한다. 생성된 `VisitMapperImpl`에 매핑이 들어갔는지 확인한다.
6. `mapper/PetMapper.java`: `@Mapper(uses = VisitMapper.class)`를 추가한다. 생성된 `PetMapperImpl`이 `visitMapper.toVisitDto`를 호출하는지, 기동 시 순환 의존 오류가 없는지 확인한다.
7. 컨트롤러 테스트 추가: `VisitRestControllerTests`, `OwnerRestControllerTests`(6.1절).
8. 전체 빌드: `.\mvnw.cmd -B package`. 서버를 띄워 curl로 `recentVisit` 값을 확인한다.

**Frontend** (7절의 결정을 받은 뒤에)

9. `client/src/types/index.ts`: `IVisit.recentVisit?: boolean`
10. 신규 `client/src/components/visits/VisitDetails.tsx`: 방문일, "최근 방문" 여부, 설명 전문(`white-space: pre-wrap`)을 보여준다.
11. `client/src/components/owners/PetsTable.tsx`:
    - `VisitsTable`에서 `visit.recentVisit`이면 "최근 방문" 라벨(`<span className='label label-info'>최근 방문</span>`)과 행 강조(`className='info'`)를 붙인다.
    - 행을 클릭하면 선택 상태를 바꾼다. `VisitsTable`을 상태 있는 클래스 컴포넌트로 바꾸거나, 선택 상태를 `OwnersPage`로 올린다.
    - 선택된 방문이 있으면 `<VisitDetails/>`를 표시한다.
    - 날짜는 계산하지 않는다(R3).

### 5.2 대안과 선택 이유

**(A) 판정 위치**

| 대안 | 장점 | 단점 | 판단 |
|---|---|---|---|
| A1. 별도 정책 컴포넌트 + `Clock` 주입, 매퍼에서 호출 | 기준이 한 곳에 있다. 보고서나 다른 화면이 서비스 계층에서 그대로 재사용한다(R3). `Clock.fixed`로 경계 테스트가 결정적이다. | 새 빈 2개(`Clock`, 정책) | **선택** |
| A2. 엔티티 `Visit#isRecent(LocalDate today)` 도메인 메서드 + 매퍼 `@Context` | 도메인에 의미가 붙는다. | 매퍼마다 `today`를 넘기는 배선이 필요하고, 호출 쪽이 시계를 알아야 한다. | 보류 |
| A3. 저장소 쿼리에서 계산(`CASE WHEN visit_date >= ...`) | DB에서 끝난다. | 저장소 3벌(jdbc 문자열 SQL, JPQL, @Query)을 모두 고쳐야 하고, DB별 날짜 함수가 다르고, 엔티티에 필드가 생긴다. | 기각 |
| A4. Frontend에서 계산 | 간단하다. | R3에 정면으로 어긋난다. | 기각 |
| A5. 매퍼 안 `expression="java(LocalDate.now()...)"` | 파일이 적다. | 시계를 고정할 수 없어 경계 테스트가 자정 근처에서 흔들린다. 기준이 매퍼 두 곳에 흩어진다. | 기각 |

**(B) 중첩 visits의 매핑 경로**

| 대안 | 내용 | 판단 |
|---|---|---|
| B1. `PetMapper`에 `uses = VisitMapper.class` | 매핑이 한 벌로 합쳐진다. 부수효과로 중첩 visits의 `petId`가 채워진다. | **권고**. 단 부수효과는 사람이 승인해야 한다(7절). |
| B2. `PetMapper`에 별도 `VisitDto toVisitDto(Visit)` 선언 + `@Mapping(target="recentVisit"...)`, `petId`는 지금처럼 비워 둠 | 기존 응답이 바이트 단위로 유지된다(새 필드만 추가). | B1이 거절되면 이쪽. 매핑 정의가 두 곳에 남아 다음 변경 때 또 빠질 위험이 있다. |

**(C) 상세 보기 방식**

| 대안 | 내용 | 판단 |
|---|---|---|
| C1. 같은 화면에서 선택 → 아래 상세 패널 | 이미 받은 데이터를 쓰므로 추가 API 호출이 없다. 라우트가 그대로라 다른 화면에 영향이 없다. | **권고** |
| C2. 새 라우트 `/owners/:o/pets/:p/visits/:v` + `GET /api/visits/{id}` | URL로 공유할 수 있다. | 라우트·페이지를 새로 만들어야 한다. 기존 `url()` 슬래시 문제와 단수 경로 문제를 또 만나게 된다. |

---

## 6. 검증 계획

### 6.1 추가할 테스트

**`VisitRecencyPolicyTests`** (단위, `Clock.fixed(2026-10-04T00:00 KST)` 등으로 고정)

| 케이스 | 방문일 | 기대값 (권고 기준 `today-30 ~ today`) |
|---|---|---|
| 오늘 | today | true |
| 어제 | today-1 | true |
| 29일 전 | today-29 | true |
| **정확히 30일 전** | today-30 | **true** (경계, 1.2절 결정에 따라 바뀜) |
| **31일 전** | today-31 | **false** (경계) |
| 내일(미래) | today+1 | false |
| null | null | false |
| 시간대 경계 | `Clock`을 UTC 15:00(KST 다음 날 00:00)로 둔 경우 | 선택한 ZoneId 기준 날짜로 판정되는지 |
| 월말·윤년 | 예: today=2028-03-01, 방문일=2028-01-31 | `minusDays`로 계산되는지(30일 전 = 2028-01-31) |

**컨트롤러 테스트** (기존 패턴: `@MockBean ClinicService` + `jsonPath`)

- 오늘 날짜를 고정하려면 테스트 클래스에 `@MockBean Clock`을 두거나(매번 `instant()`·`getZone()` 스텁) 고정 `Clock`을 `@TestConfiguration`으로 등록한다. 기존 테스트가 `LocalDate.now()`를 쓰는 점과 충돌하지 않도록, 새로 추가하는 테스트 데이터만 고정 시계 기준으로 만든다.
- `VisitRestControllerTests`: `GET /api/visits/{id}`에서 최근 방문은 `$.recentVisit == true`, 31일 전 방문은 `false`. `GET /api/visits`에서는 둘이 섞인 목록을 검증한다.
- `OwnerRestControllerTests`: `GET /api/owners/{id}`에서 한 반려동물에 30일 전 방문과 31일 전 방문을 섞어 두고 `$.pets[0].visits[?(@.id==..)].recentVisit`를 각각 검증한다. 이것이 **인수 기준 1을 서버에서 검증**하는 테스트이고, 동시에 `PetMapper` 경로가 빠지지 않았음을 막는 회귀 테스트다.
- (B1을 택한 경우) 같은 테스트에서 중첩 visits의 `petId` 값도 검증한다.
- `PetRestControllerTests`: `GET /api/pets/{id}`의 `$.visits[*].recentVisit`가 들어 있는지.
- 회귀: `POST /api/owners/{o}/pets/{p}/visits`의 상태 코드(201)와 기존 필드가 그대로인지(기존 테스트가 있으면 그대로 통과해야 한다).

### 6.2 돌릴 기존 테스트

- `.\mvnw.cmd -B test`: 전체. 기준선은 183개 통과, 여기에 추가분이 더해진다.
- 그중 특히 `VisitRestControllerTests`, `OwnerRestControllerTests`, `PetRestControllerTests`(매퍼 변경 영향), `ClinicServiceJdbcTests`/`JpaTests`/`SpringDataJpaTests`(컨텍스트에 새 빈이 들어가도 로딩되는지).
- `.\mvnw.cmd -B package`: 빌드와 생성 코드 확인.
- (선택) CI 동등 `mvn -B install`, 그리고 JaCoCo `verify` 기준. 현재 통과 여부부터 미확인이다.

### 6.3 API 수준 수동 확인 (Frontend 없이도 가능)

1. `.\mvnw.cmd spring-boot:run`
2. `POST /petclinic/api/owners/6/pets/7/visits`로 방문 3건을 만든다: 오늘, 30일 전, 31일 전.
3. `GET /petclinic/api/owners/6`에서 pet 7의 visits 중 앞의 두 건만 `recentVisit:true`인지 확인한다. 기존 2013년 방문은 `false`여야 한다.
4. Swagger UI(`/petclinic/swagger-ui.html`)의 `Visit` 스키마에 필드와 설명이 보이는지 확인한다.
5. 서버를 종료한다.

### 6.4 화면 확인

AGENTS.md의 방식(`playwright-cli open --browser=msedge http://localhost:4444/...` → `snapshot` → 방문 행 `click` → 상세 확인 → `screenshot` → `close`)을 쓴다. 다만 **지금은 불가능하다**(7절). Frontend를 띄울 수 있게 되기 전까지 화면 부분은 "미확인"으로 보고해야 한다.

---

## 7. 위험과 사전 확인 필요 사항

### 7.1 Frontend 화면 부분: 지금 상태로는 구현도 검증도 끝낼 수 없다

현재 상태[확인 + AGENTS.md 기록]:

1. **빌드·실행 불가**: webpack 1 형식 설정을 webpack 5로 돌리고 있고 `webpack-cli`가 없다. `npm start`는 즉시 종료되고 `npm run build:*`는 실패한다.
2. **테스트 불가**: jest 29가 `scriptPreprocessor` 옵션을 거부해 모든 스위트가 실행 전에 실패한다.
3. **빌드를 고쳐도 대상 화면이 데이터를 못 받는다**: `OwnersPage`가 `url('/api/owner/' + id)`를 호출한다. 단수 경로이고 `//api` 이중 슬래시까지 겹쳐 400이 난다[확인]. 즉 CR-001이 고치려는 "반려동물별 방문 목록" 화면은 **지금도 방문 목록을 보여주지 못한다.**
4. **제약 "기존 진료 기록 등록 기능 불변"의 현재 기준선이 이미 고장 나 있다**: `VisitsPage`도 같은 단수 경로로 owner를 불러온다. 제출할 때는 `'/api/owners/...'`에 `url()`이 앞에 슬래시를 하나 더 붙여 이중 슬래시가 된다. 게다가 성공 판정이 `status === 204`인데 Backend는 `201`을 돌려준다[확인: 실행]. 이 문제들은 CR-001과 별개다.

**사람이 정해야 할 것 (택1 또는 조합)**

| 선택지 | 내용 | 결과 |
|---|---|---|
| F1 (권고) | **CR-001을 Backend 범위로 먼저 완료**한다(API 필드, 판정 정책, 서버 경계 테스트). 인수 기준 2(서버 경계 테스트)와 4(기존 테스트)는 이걸로 충족된다. Frontend 툴체인 복구와 경로 불일치 수정은 **별도 CR**로 처리하고, CR-001의 화면 부분은 그 뒤에 한다. | 인수 기준 1·3의 화면 확인은 뒤로 미뤄진다. |
| F2 | Frontend 코드까지 작성하되 빌드·실행·화면 확인은 "미확인"으로 보고한다. | TypeScript 2.0 / React 15 코드가 컴파일되는지조차 확인할 수 없다. 리뷰로만 검증하게 된다. |
| F3 | CR-001 범위를 넓혀 Frontend 빌드 복구와 경로 수정까지 포함한다. | webpack·jest 설정과 의존성을 바꿔야 한다. AGENTS.md "범위" 규칙상 사전 승인이 필요하고, 작업량이 CR-001 본체보다 클 수 있다. 경로 수정은 "등록 기능 동작 불변" 제약과도 부딪친다(고장 난 동작이 바뀜). |

### 7.2 그 밖의 결정·확인 사항

| # | 항목 | 내용 |
|---|---|---|
| D1 | 30일 경계 | `today-30` 포함 여부. 요구 문구(29)와 인수 기준(30)이 충돌한다. 1.2절 참고. |
| D2 | 시간대 | `Asia/Seoul`로 고정할지, JVM 기본값을 쓸지. 운영 서버의 시간대를 알려 주면 좋다. |
| D3 | 미래 날짜 방문 | `false`로 볼지(권고) |
| D4 | 필드명 | `recentVisit`(권고) |
| D5 | `PetMapper` 통합(B1)의 부수효과 | owner·pet API의 중첩 visits `petId`가 null에서 실제 값으로 바뀐다. 허용(B1)인지, 기존 응답을 엄격히 유지(B2)할지. |
| D6 | 상세 보기 형태 | 같은 화면 패널(C1, 권고)인지 별도 페이지(C2)인지 |
| D7 | 새 빈·설정 추가 | `Clock` 빈과 설정 클래스 1개를 새로 만든다. 의존성 추가는 없다. AGENTS.md "설정 변경은 먼저 묻는다"에 해당할 수 있어 승인이 필요하다. |

### 7.3 기술 위험

- **매핑 누락이 조용히 지나간다**: MapStruct `unmappedTargetPolicy`가 WARN이라, 한쪽 매퍼에서 `recentVisit` 매핑이 빠져도 빌드는 성공하고 `null`이 나간다. 이것은 owner API 경로 테스트(6.1절)로 막는다.
- **매퍼 순환 의존**: B1 적용 후 기동 확인이 필요하다(3.3절).
- **테스트 컨텍스트 빈 누락**: 컨트롤러 테스트가 실제 매퍼 빈을 쓰므로 `Clock`·정책 빈이 테스트 컨텍스트에 없으면 컨트롤러 테스트가 모두 깨진다.
- **응답이 날짜에 따라 달라짐**: 같은 데이터도 날이 바뀌면 `recentVisit`이 바뀐다. 이 응답을 캐시하는 소비자가 있다면 하루 단위로 값이 어긋날 수 있다(저장소 안에는 그런 캐시가 없음[확인: ETag 정의만 있음]).
- **초기 데이터에 최근 방문이 없다**: 2013년 데이터뿐이라, 화면이나 API 수동 확인 때는 방문을 직접 등록해야 한다(6.3절). 초기 데이터를 바꾸는 것은 DB 데이터 변경이라 권하지 않는다.
- **보고서 재사용**: R3에서 말한 "보고서"가 무엇인지(다른 시스템인지, 이 Backend의 새 API인지) 알 수 없다. 다른 시스템이라면 그쪽은 Java 정책 클래스를 재사용할 수 없으므로, 기준(일수, 경계, 시간대)을 문서로 명시해 공유해야 한다.
