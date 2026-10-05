# AGENTS.md

<!-- harness:core:start -->
## 공통 규칙 (Harness Core)

- **완료 기준**: 코드를 바꿨으면 이 프로젝트의 빌드와 관련 테스트를 실행해 통과를 확인한다. 화면이 바뀌는 변경이면 앱을 띄워 브라우저로 해당 화면을 확인한다. 실행하지 못했거나 확인하지 못한 것은 완료 보고에 "미확인"으로 적는다.
- **프로젝트 사실**: 빌드·테스트·실행·화면 확인 방법은 아래 "프로젝트" 절에 있다. 거기에 없으면 저장소에서 찾아 실제로 실행해 확인한 뒤, "프로젝트" 절에 추가할 내용을 제안한다.
- **화면 확인 도구**: `playwright-cli`를 쓰고, PC에 설치된 Edge를 그대로 쓴다. `playwright-cli open --browser=msedge <http 주소>`로 연 뒤 `snapshot`, `click <ref>`, `console`, `screenshot`으로 확인하고 `close`로 닫는다. 전체 명령은 `playwright-cli --help`에 있다. `file:` 주소는 막혀 있으므로 앱을 띄워 http 주소로 연다.
- **라이브러리 사용법**: 기억에 의존하지 않는다. 이 프로젝트에 설치된 버전을 확인하고, 로컬에 있는 그 버전의 자료(패키지의 타입 정의·README·소스, 의존성의 sources·javadoc)를 먼저 읽는다. 로컬에 없고 웹 조회가 허용된 환경이면 해당 라이브러리의 공식 문서 사이트만 본다.
- **비밀 정보**: `.env`, 인증서, 키 파일, 접속 정보가 든 설정 파일의 내용을 읽거나 출력하거나 커밋하지 않는다.
- **범위**: 요청받은 변경만 한다. 관련 없는 리팩터링, 의존성 추가, 설정 변경은 먼저 묻는다.
<!-- harness:core:end -->

## 프로젝트

<!--
이 절은 프로젝트마다 다르다. 일하는 순서가 아니라 이 프로젝트의 사실만 적는다.
init-project 실행 후 agent에게 저장소를 읽고 채우게 한 다음, 사람이 실제로 실행해 확인한다.
확인하지 못한 항목은 지우지 말고 "미확인"이라고 적는다.
-->

### 구조

- Frontend 위치: `client/` — React 15 + TypeScript 2.0 + react-router 2 SPA. 진입점 `client/src/main.tsx`, 화면 컴포넌트 `client/src/components/{owners,pets,visits,vets}/`.
- Backend 위치: 저장소 루트(`pom.xml`, `src/main/java/org/springframework/samples/petclinic/`) — Spring Boot 3.2.1, Java 17, REST 전용(서버 렌더링 화면 없음).
- 화면에서 API, API에서 DB까지 따라갈 때 알아야 하는 것:
  - 화면 라우팅: `client/src/configureRoutes.tsx`. API 호출은 각 페이지 컴포넌트 안에서 `client/src/util/index.tsx`의 `url()`·`submitForm()`으로 직접 `fetch`한다(별도 API 클라이언트 계층 없음). Backend 주소는 `webpack.config.js`의 `__API_SERVER_URL__`(DefinePlugin), 없으면 `util/index.tsx`의 기본값.
  - API 계약: `src/main/resources/openapi.yml`이 원본이다. 빌드 시 openapi-generator가 `target/generated-sources/openapi/`에 인터페이스(`rest.api.*Api`)와 DTO(`rest.dto.*Dto`)를 생성하고, `rest/controller/*RestController.java`가 그 인터페이스를 구현한다. 경로 매핑 어노테이션은 컨트롤러가 아니라 생성된 인터페이스에 있다(컨트롤러에는 클래스 레벨 `@RequestMapping("/api")`만).
  - DTO↔엔티티 변환: `mapper/*Mapper.java`(MapStruct, MyBatis 매퍼 아님).
  - 서비스: `service/ClinicServiceImpl.java`, `service/UserServiceImpl.java`.
  - 저장소 계층은 같은 인터페이스(`repository/*Repository.java`)에 구현이 3벌 있고 Spring 프로필로 하나만 활성화된다: `repository/jdbc/`(SQL 문자열이 Java 코드 안에 있음, 프로필 `jdbc`), `repository/jpa/`(JPQL, 프로필 `jpa`), `repository/springdatajpa/`(`@Query`, 프로필 `spring-data-jpa`, **기본값**).
  - 엔티티: `model/`. 스키마·초기 데이터: `src/main/resources/db/{hsqldb,mysql,postgresql}/initDB.sql`, `populateDB.sql`. ER 다이어그램: `petclinic-ermodel.png`.

### 명령

| 목적 | 명령 | 실행 위치 |
|---|---|---|
| 의존성 설치 | Backend: 별도 명령 없음(mvnw가 빌드 시 받음). Frontend: `npm ci --legacy-peer-deps --ignore-scripts` — 설치는 되지만 아래 Frontend 명령이 모두 실패하므로 쓸모 있는 설치인지는 미확인. README의 `npm install`은 실패(peer 의존성 충돌: `extract-text-webpack-plugin@3`이 webpack 3 요구, 실제는 webpack 5). `--legacy-peer-deps`만 붙이면 postinstall `typings install`이 폐쇄된 api.typings.org에서 404로 실패 | Frontend: `client/` |
| Backend 빌드 | `.\mvnw.cmd -B package` (확인: 테스트 포함 BUILD SUCCESS, `target/spring-petclinic-rest-3.2.1.jar`). CI는 `mvn -B install -Djacoco.skip=true -DdisableXmlReport=true` — `verify` 단계의 JaCoCo 커버리지 기준(라인 85%, 분기 66%) 통과 여부는 미확인 | 루트 |
| Backend 테스트 (전체) | `.\mvnw.cmd -B test` (확인: 183개 통과) | 루트 |
| Backend 테스트 (단일) | `.\mvnw.cmd -B test "-Dtest=OwnerRestControllerTests"` (확인: 통과) | 루트 |
| Backend 실행 | `.\mvnw.cmd spring-boot:run` (확인: 9966 포트, context path `/petclinic` 로 기동) | 루트 |
| Frontend 빌드 | `npm run build:clean` / `npm run build:prod` — 미확인(실패). `webpack-cli` 미설치이고, `webpack.config*.js`가 webpack 1 형식(`loaders`, `preLoaders`, `tslint` 키)이라 webpack 5에서 설정 검증 오류. `build:prod`는 `NODE_ENV=...` 문법이라 Windows cmd에서도 동작 안 함 | `client/` |
| Frontend 테스트 | `npm test` (jest 29) — 미확인(실패). `package.json`의 jest 설정 `scriptPreprocessor`가 jest 29에서 제거된 옵션이라 3개 스위트 모두 실행 전 실패 | `client/` |
| Frontend 실행 | `PORT=4444 npm start` (= `node server.js`, Windows는 `$env:PORT=4444; npm start`) — 미확인(실패). webpack 5가 설정 객체를 거부해 즉시 종료 | `client/` |
| 린트·포맷 | Frontend: `npx tslint -c tslint.json 'src/**/*.ts' 'src/**/*.tsx'` (실행은 됨, 기존 위반 1건으로 exit 2). Backend: 린트 도구 없음, 포맷은 `.editorconfig`만 | `client/` |

### 화면 확인

- 로컬 주소: Frontend는 `http://localhost:4444`(README 기준, 기동 불가로 미확인). Backend API는 `http://localhost:9966/petclinic/api/...`, Swagger UI는 `http://localhost:9966/petclinic/swagger-ui.html`(확인: 200). README의 `localhost:8080`, `/api/pettypes` 주소는 옛 정보로 틀림.
- 로그인 방법: 기본 설정(`petclinic.security.enable=false`, `src/main/resources/application.properties`)에서는 인증 없음. 켜면 HTTP Basic + JDBC 인증이며, 계정은 `users`·`roles` 테이블에 있고 초기 데이터는 DB별 `src/main/resources/db/<hsqldb|mysql|postgresql>/populateDB.sql`에 있다. Frontend에는 로그인 화면이 없다.
- 실행에 필요한 선행 조건: 기본 프로필 `hsqldb,spring-data-jpa`는 인메모리 HSQLDB라 외부 DB·환경 변수 불필요(기동할 때마다 `populateDB.sql`로 초기화). MySQL/PostgreSQL은 `spring.profiles.active` 변경 + `application-mysql.properties`/`application-postgresql.properties`의 접속 정보 필요(설정 안내: `db/mysql/petclinic_db_setup_mysql.txt`, `db/postgresql/petclinic_db_setup_postgresql.txt`). JDK 17. Frontend는 Backend가 먼저 떠 있어야 한다.

### 이 프로젝트의 비표준 규칙

- README는 대부분 원본 spring-petclinic(JSP·Dandelion·Bower 시절) 내용이라 현재 코드와 맞지 않는다. 명령·주소는 README가 아니라 이 절과 `pom.xml`, `application.properties`를 기준으로 한다.
- 이 저장소는 서로 시기가 다른 두 프로젝트를 합친 것이다: Backend는 spring-petclinic-rest 3.2.1, Frontend는 그보다 훨씬 오래된 spring-petclinic-reactjs. 둘이 맞지 않는 곳이 있다:
  - Frontend는 `/api/owner/{id}`(단수)를 호출하지만 Backend에는 `/api/owners/{id}`만 있다(확인: 단수 경로 400).
  - Frontend 일부 호출이 `url('/api/...')` 형태라 `.../petclinic//api/...`처럼 슬래시가 겹쳐 400이 난다(확인).
- API를 바꿀 때는 `openapi.yml`을 먼저 고친다. 컨트롤러 메서드 시그니처와 DTO는 여기서 생성되므로 생성 파일(`target/generated-sources/openapi/`)을 직접 고치지 않는다.
- 저장소 계층을 고치면 `jdbc`·`jpa`·`springdatajpa` 세 구현을 함께 맞춘다. 서비스 테스트(`ClinicServiceJdbcTests`, `ClinicServiceJpaTests`, `ClinicServiceSpringDataJpaTests`)가 세 프로필을 모두 돈다.
- 테스트용 `src/test/resources/application.properties`는 `petclinic.security.enable=true`라 테스트에서는 보안이 켜져 있다(실행 기본값과 반대). 컨트롤러 테스트는 `@WithMockUser`로 역할을 준다.
- 권한은 컨트롤러 메서드의 `@PreAuthorize("hasRole(@roles.OWNER_ADMIN)")` 형태이며 역할 이름은 `security/Roles.java`에 있다.
- 기본 로그 레벨이 `logging.level.org.springframework=DEBUG`라 Backend 로그가 매우 많다.
- `.travis.yml`(Node 6, JDK 8)은 더 이상 맞지 않는 옛 CI다. 현재 CI는 `.github/workflows/maven-build.yml`(Backend만 빌드)이고, Frontend를 검사하는 CI는 없다.
