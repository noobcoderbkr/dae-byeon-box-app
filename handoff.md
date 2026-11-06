# Model Input Handoff

## English

### Accident Notification Entry (2026-10-17, Latest)

Tapping an accident notification opens the owned case's **10-second accident countdown**,
then first response with the same case ID, not Home. Manual entry keeps its countdown too. Notification
listeners and cold-launch retrieval start before session restoration; navigation waits for
authentication, current collection consent, and backend ownership validation. FCM token
permission/registration is separate. A later explicit tap may reopen the same case;
concurrent stale validations and account/consent changes remain fenced.

### 한국어 해석: 사고 알림 진입

사고 알림을 누르면 해당 사건의 **10초 사고 감지 카운트다운**으로 이동한 뒤 같은 사건의
초동대처로 이어집니다. 홈으로 보내지 않으며 수동 접수도 카운트다운을 유지합니다. 앱 시작부터 알림을 수신하되
로그인·현재 수집 동의·사건 소유권을 확인한 뒤 이동합니다. 같은 사고의 알림을 다시
눌러도 재진입할 수 있고 계정 변경·동의 철회·뒤늦은 검증 결과는 계속 차단합니다.

### Location, Weather And Speed Presentation (2026-10-17)

This section supersedes older Mock-warning presentation notes. The analysis screen explains the registered GPS address/road and the selected road type, shows validated Open-Meteo current weather with attribution, and displays `43 km/h`. It does not show Mock/demo labels. Internal GPS/speed provenance and the legal-reference disclaimer remain. Missing weather or model predictions are not fabricated. The road-selection hint is “사용자께서 도로유형 선택 시 더욱 더 정확한 결과가 나옵니다.” Road choices and optional movement answers still trigger the same backend reanalysis contract.

The local backend pins the owned `신호_교차로` video registered at `2026-10-16T20:12:28.804784+00:00`, GPS `37.497989, 127.0277`. Playback, map and analysis must retain the returned case ID. Current weather is not accident-time weather; old saved weather is not displayed as current after expiry. No device/service credentials are added to the app.

### 한국어 해석: 위치·기상·속도 표시

이 항목은 이전 목업 경고 표시 설명보다 우선합니다. 분석 화면은 등록 GPS의 주소·도로와 선택한 도로유형을 설명하고 Open-Meteo 출처를 포함한 현재 기상 및 `43 km/h`를 표시합니다. 목업·시연 문구는 화면에 노출하지 않으며 내부 출처와 법적 참고용 안내는 유지합니다. 없는 기상·모델 결과를 만들지 않습니다. 도로 선택 안내 문구를 변경했으며 도로 토글과 선택형 거동 답변의 재분석 계약은 동일합니다.

로컬 백엔드는 지정된 `신호_교차로` 영상과 등록 GPS를 사용합니다. 영상·지도·분석에서 반환된 동일 사건 ID를 유지합니다. 현재 기상을 사고 당시 기상으로 안내하지 않고 오래된 저장 기상도 현재 날씨로 표시하지 않습니다. 앱에 장치·서비스 인증정보를 넣지 않습니다.

### Filming Demo Fixes (2026-10-17, Latest)

Manual incident entry now offers **Use received video** with its received date, or explicitly starts a new incident without video. Using a received video preserves that owned hardware case through countdown, playback, map and analysis. An empty incident offers **View latest received video** as an explicit navigation, never silently attaches old evidence, and cannot start AI analysis without an original. Already-granted consent restores at startup without re-acceptance; explicit consent management and read-only account/history access remain available.

The local operator configured all eight existing accounts as separate collectors of the same demonstration source. Seven accounts have current collection consent and passed authenticated video/map access; the eighth remains pending consent. No consent was granted on their behalf and no personal chats/profiles were shared. Future accounts still need operator provisioning. The map adapter now supports the collector's actual same-origin `/api/map/image.png` URL, retaining event identity, image limits and redirect protection. Actual simulator playback and the 1200-by-800 map were verified; assumed GPS remains labeled. MODEL and LAW are real, while context/weather/speed and chatbot prose remain Mock.

### 한국어 해석: 시연 동선 수정

사고 접수에서 수신 날짜를 확인하고 **수신 영상 사용**을 선택하면 같은 하드웨어 사건으로 카운트다운·재생·지도·분석을 진행합니다. **영상 없이 새 사고 접수**는 별도 사건입니다. 빈 사건에는 **최신 수신 영상 보기**를 제공하지만 다른 영상을 몰래 결합하지 않으며 원본이 없으면 AI 분석을 실행하지 않습니다. 기존 동의는 재시작 시 복원하고 동의 관리·계정 관리·기록 열람 경로는 유지합니다.

기존 로컬 8개 계정의 별도 수신 연결을 설정했습니다. 동의 완료 7개는 인증된 영상·지도 조회를 통과했고 나머지 1개는 동의 대기 상태입니다. 동의 자동 승인이나 다른 계정의 채팅·프로필 공유는 하지 않습니다. 이후 생성한 계정은 운영자 연결 설정이 필요합니다. 실제 지도 URL 형식을 지원해 시뮬레이터에서 영상과 1200×800 지도를 확인했으며 가정 GPS 표시도 유지합니다. MODEL·LAW는 실제 서비스, 환경·기상·속도·챗봇 문구는 Mock입니다.

### Hardware Connection And Accident Entry (2026-10-17)

This section supersedes earlier demonstration-notification and collector-unavailable notes. `GET /api/v1/devices` returns `data.devices`: only the caller's active, operator-approved collector bindings, with the same metadata as the owned-device endpoint and no device credential. The app restores a single binding after login/cache loss; multiple bindings require selection. `POST /devices/link` still verifies ownership and operator configuration. It does not claim a physical device by public URL. Authentication, approval, configuration and network errors are shown separately.

The operator explicitly approved separate existing-owner and local-demo receivers. Ownership and prior cases are unchanged; newly received cases/files stay separate. This is a private test configuration, not a general multi-user sharing UI. Shared external source deletion waits until every referencing active case requests deletion.

Accident notifications say **“사고가 나셨습니까?”**. Opening an authenticated, consented notification validates its exact owned `case_id`, opens the 10-second accident countdown, and carries that same ID into first response and video. It never substitutes an older/latest video for an empty phone incident. A pending received-video screen checks its exact case every 5 seconds for at most 120 seconds; errors, account/case changes and leaving the screen stop the check. It does not claim that upload is underway without evidence. Simulator push tests are not proof of real FCM/APNs delivery.

Collector event IDs may contain canonical Korean characters. File paths use their exact, once-encoded UTF-8 event segment. Hardware credentials remain backend-only. Use the latest received-video entry explicitly when reviewing an older source video outside a new-incident notification.

Local verification: the latest `신호_교차로` source video (9.958 seconds, 2,369,097 bytes) was automatically received in separate cases for both approved accounts. MinIO download size/SHA256 matched. Simulator notification opening, countdown, checklist toggle, received-video playback and the app's road-toggle reanalysis all passed. Manually selecting place 1 with no extra movement produced real MODEL B 0% / A 100%; the zero question vector was retained. LAW returned six real references with `incomplete` status, not a claim of complete legal coverage. GPS is assumed; `trigger_estimated` and `clip_padded` remain visible in the model data. Final verification: 247 Flutter tests, 80 collector/API/shared-source tests, 120 worker/copy/job tests, two iOS configuration checks, clean scoped analysis and successful simulator build. This does not certify model accuracy, physical shock detection, live phone push or legal advice.

### 한국어 해석: 장치 연결 및 사고 진입

이 항목은 이전의 시연 알림·수집 서버 접속 불가 설명보다 우선합니다. `GET /api/v1/devices`는 로그인한 사용자의 활성·운영자 승인 연결만 반환하며 장치 인증정보는 포함하지 않습니다. 연결이 하나면 로그인 또는 캐시 유실 뒤 자동 복원하고, 여러 개면 선택이 필요합니다. 공개 주소만 입력해서 다른 사람의 장치를 가져올 수 없으며 로그인·승인·주소·네트워크 오류를 구분해 표시합니다.

기존 소유자와 시연 계정의 동시 수신은 운영자가 승인한 로컬 설정입니다. 소유권과 기존 사건은 그대로이고 새 사건·파일은 계정별로 분리합니다. 공유 원본의 외부 삭제는 참조하는 모든 활성 사건이 삭제를 요청할 때까지 보류합니다.

알림은 **“사고가 나셨습니까?”**로 표시합니다. 누르면 로그인·동의·해당 사건 소유권을 확인한 뒤 10초 카운트다운으로 이동하며 같은 사건으로 초기 대응·영상 확인을 이어갑니다. 새 사건에 다른 최신 영상을 몰래 붙이지 않습니다. 영상 대기는 해당 사건만 5초 간격으로 최대 120초 확인하며 오류·계정 변경·화면 이탈 시 중단합니다. 시뮬레이터 알림 검증은 실제 휴대폰 푸시 수신 검증과 별개입니다.

한글 사건명은 정규형만 허용하고 파일 경로의 사건 구간을 UTF-8로 한 번만 인코딩합니다. 장치 인증정보는 백엔드에만 둡니다. 기존 영상을 확인할 때는 최신 수신 영상 메뉴를 명시적으로 사용합니다.

로컬 검증에서는 최신 `신호_교차로` 영상(9.958초, 2,369,097바이트)을 두 승인 계정의 별도 사건으로 자동 수신했고 MinIO 다운로드 크기·SHA256이 일치했습니다. 알림→카운트다운→체크리스트 토글→영상 재생→앱 도로 토글 재분석을 확인했습니다. 신호교차로를 직접 선택하고 추가 거동을 비웠을 때 실제 MODEL은 B 0%·A 100%, 질문은 0벡터였습니다. 실제 LAW 근거 6건은 일부 결과로 표시합니다. GPS는 가정값이며 충격 시각 추정·짧은 클립 패딩 경고도 유지합니다. 최종 검증은 앱 247개, 수집·API·공유 원본 80개, 워커·복사본·작업 120개, iOS 설정 2개 시험 통과 및 정적 검사·시뮬레이터 빌드 성공입니다. 모델 정확도나 실제 충격 감지, 휴대폰 푸시, 법률 판단을 인증하는 결과는 아닙니다.

### Real MODEL And LAW (2026-10-17)

This section supersedes older LAW Mock/unavailable notes below. The matching local API/worker now use real Windows GPU MODEL and LAW services. The app's analysis and saved-report views render structured legal issues, statutes/precedents, source labels, and validated official links. Search uses the canonical `/api/v1/law/search` response, not the obsolete port-9000 LAW API or fabricated court/date/ratio fields.

Only `providers.law == real` with complete/incomplete LAW status can expose evidence. A supplied push job ID is loaded through its case-scoped job endpoint and checked against the optional report ID; opening a result never silently starts a new analysis. User keywords/facts can be updated or cleared without promoting them to video facts or changing canonical model ratios. Missing data remains unavailable, not 50:50.

Use `--dart-define=API_BASE_URL=http://127.0.0.1:8000` for the simulator on the backend Mac. The opening demonstration notification uses Apple's simulator push payload with real case/job/report IDs; it is not proof of live FCM/APNs delivery. No real notification credentials are embedded in Flutter. LAW uses a historical offline corpus; address/weather/speed remain Mock.

The current iOS 26 Apple Silicon runtime cannot install the MLKit-dependent x86 simulator build. For this local preview only, the two unsupported OCR plugins are excluded from ignored generated native build files and an arm64 build is used. `pubspec.yaml` and real-device OCR sources remain unchanged; license numbers can be entered manually in the preview. Regenerating native plugin files restores the normal device configuration. Do not publish the preview's generated Podfile lock as a complete device dependency lock. Changes are local until separately committed/pushed.

The pinned Firebase Messaging plugin observes the application launch notification and misses it when registered by an implicit UIScene engine. This build retains the application lifecycle: plugins register before launch completes and the preserved scene manifest has an `_` prefix, following [Flutter's temporary compatibility procedure](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate#temporarily-disable-uiscene). Upgrade and verify Messaging before re-enabling UIScene; this is required before Xcode 27/iOS 27 SDK builds. Run `python3 test/ios_config_test.py` alongside Flutter tests while this compatibility configuration remains.

Simulator login uses an Xcode-generated ad-hoc signature with only the approved app-specific keychain group. Build with code signing enabled and the temporary simulator entitlements rather than applying restricted entitlements directly with `codesign` after an unsigned build. No shared keychain group, production signing identity, authentication bypass, or phone-side model/LAW credentials were added.

Verified on 2026-10-17: 216 Flutter tests, 2 native-configuration checks and the arm64 simulator build passed; scoped analysis reported no issues. Login survives an app update/relaunch. Tapping the simulator completion notification opens the exact saved job/report with real MODEL ratios and 9 LAW references. Report prose, address/weather and speed remain Mock. This used the retained original verification video, not a new collector download; the collector was unavailable. Live phone FCM delivery and OCR are not covered by this preview.

### Additional Upstream Features (2026-10-17)

Compared `pth888/driveguard-ai` default branch commit `a87d415` and added only missing features:

- Received video: `Accident location` expands an on-demand PNG map with route/source attribution, recorded GPS and capture time. Assumed GPS stays labeled. No GPS, rendering pending, authentication failure and unavailable collector states remain explicit. Case/account changes clear old map evidence. Address/weather/speed providers are unchanged.
- My Page: separate `Server connection` and `Name-only registration` flows. Connection takes a collector HTTPS origin and front/rear choice (`violet-dashcam-1`/`violet-dashcam-2`). Success requires an existing trusted owner/device mapping confirmed by the backend; typing a public source ID never proves ownership. Failed links preserve the previously saved backend device ID. Hardware credentials are never stored in the phone.

Deploy the companion backend changes in this integration checkout with the app. The previously published backend revision alone does not provide these new endpoints:

| API | Result |
| --- | --- |
| `POST /api/v1/devices/link` | User Bearer; body `{name, server_url, device_id, position}`; 200 `data.device` with the backend `id`, `name` and `collector: {server_url, device_id, position}`. The collector `device_id` is not the backend ID. 409 `device_not_linked` means the operator must authorize the owner mapping first; 422 rejects invalid origin/position/name. |
| `GET /api/v1/devices/{backend_id}` | Owned device metadata; `collector: null` means unbound/revoked. 401/403/404 retain their usual meaning. No device token is returned. |
| `GET /api/v1/cases/{case_id}/map` | User Bearer; 200 `data.map` with `case_id`, `status` (`ready`, `pending`, `no_gps`, `unavailable`), nullable `image_png_base64`, `has_route`, nullable `lat`, `lon`, `captured_at`, `gps_is_assumed`, nullable `retry_after_seconds`. Deleted/deleting cases cannot return maps. |

The backend queries its configured collector with `Blackbox-Collector/1.0`, optional read-only `COLLECTOR_TOKEN` (never delete credentials), strict event-scoped `/files/<device>/<event>/<name>.png[?v=<digits>]` paths, no redirects, a 2 MiB image limit and 4096-pixel dimension bounds. It proxies bytes rather than giving the phone collector credentials or arbitrary remote URLs. No new database tables, permanent map copies, SDKs or dependencies were added. Retain OpenStreetMap attribution. Capture time is device-reported, not certified timing.

The source repository's direct collector/LLM calls, placeholder credentials, fabricated 50:50/error fallbacks and local-only "connection success" were not ported. Audio capture remains excluded by the earlier agreed evidence scope. Existing video/GPU/road questions, consent and legal disclaimers remain intact.

Verification: 203 Flutter tests passed, backend suite 724 run with 24 environment-gated skips, and all 7 new backend tests passed after the canonical-path hardening. These are isolated tests, not phone/physical-pairing acceptance. Live collector map probing returned HTTP 530/Cloudflare 1033, so actual generated-map rendering must be checked after collector recovery. No commit/push or running-service restart was performed for this feature update.

### Local Feedback Fixes (2026-10-16)

- Consent choices remain drafts until `Agree and continue` completes the required server writes. OS location permission does not finish collection consent or navigate home.
- After consent, an incomplete profile opens insurance company/contact and license-number registration. License entry follows the backend text/length contract; it is not a government license verification.
- Device credentials are no longer modeled, retained, displayed or copied by the general app client. Backend hardware provisioning/authentication remains unchanged. Name-only registration is not physical collector pairing, and re-registration never silently revokes a previously registered device.
- Safety checklist items toggle independently. Emergency/insurance buttons ask for confirmation before launching the phone app; failure is visible. The iOS simulator cannot place real calls.
- Vehicle descriptions are optional for every road. Signal/roundabout secondary choices are optional and can be deselected; no answer sends null/zero-vector input, not an invented movement.
- Current local regression: 174 Flutter tests pass and touched-file analysis is clean. The rebuilt iOS Simulator shows the received original and the actual B 30% / A 70% GPU report; this is not physical-phone acceptance. A 20fps off-grid seek exposed a 149-frame preprocessing bug; the 150-frame fix passes 18 preprocessing tests and the model-service suite (160 pass, 1 skip).
- Home and the waiting-video state now offer `View latest blackbox video`. Authenticated `GET /api/v1/cases/latest-hardware` returns only an owned, non-deleting collector case with a received original (`data.case`, or null). The app opens that exact case at the video step and preserves its ID through analysis; a new manual incident never silently borrows older evidence.
- Video state carries its case ID. The player is shown only after ownership validation and an exact current-case match; slow or failed validation never displays a previously ready case's cached video.
- The latest mapped source event, `test_shock_20261015_144010Z_20261015_143940Z`, is stored in local MinIO (34,082,710 bytes, 45.4 seconds). The full original download matched its SHA256. Actual app-client requests produced real GPU reports for signal/left, roundabout/circulating, signal/no answer (zero vector), and straight. The final straight test input returned B 30%, A 70%; the road was a marked test selection, not successful GPS road inference. LAW stays unavailable; address/weather and report prose stay Mock.
- GPU serving was restarted after independent CUDA parity: L1 20/20, maximum type error 3.954e-6; L2 ratio/type decisions 20/20, minimum feature cosine 0.992787 and maximum ratio-probability error 0.030492. These pass the model team's revised 0.97/0.05 L2 gate, not the initial 0.995/0.02 gate. Training and weights were untouched. MinIO remains local/Tailnet-only.

Delivery: `CHAEMUNJEONG/blackbox-ai`, branch `GI-DOONG`, directory `app/`.
The branch includes the backend revision from `NOmodel&law_pipelineUP_backend`.
Previous published backend baseline: `1208e7d40e6229478913a80e6baf58a4617907c1`.
Git rejects `GI~DOONG`, so the hyphenated name is used. Phone installation is
not verified. The previous workflow baseline connected owned case entry, photo/audio uploads,
server case/report history, persistent chat, vehicle/insurance profiles and
case/account deletion. LAW search is explicitly mock. Opt-in FCM delivery is
implemented in the revised backend, but live acceptance is separate. See
[Service Update](../docs/backend/25-service-release.md) for current additions and
[Workflow Contract](../docs/backend/24-app-workflows.md) for the earlier baseline.

**Source and delivery:** the app originated at `pth888/driveguard-ai`, base
`92fbec0a8f7508fab0585208a458129ef2ddf6f6`, with tested implementation commit
`7b386b834d4767b230ba6cf46b0968dc94c32180`. Upstream write access was unavailable;
the user selected delivery in the Blackbox repository instead. The app is a
normal source directory, not a submodule. No upstream write access is needed.

### Setup And Contracts

Use existing `pubspec.lock` dependencies with Flutter/Dart. The verification
environment was Flutter 3.47.7 / Dart 3.13.5; use a compatible toolchain.
Run from `app/`, not the Blackbox repository root:

```bash
flutter pub get
flutter test
flutter analyze --no-fatal-infos lib/services/model_analysis_service.dart lib/services/case_service.dart lib/services/chat_service.dart lib/services/auth_service.dart lib/services/blackbox_video_service.dart lib/screens/home/main_page.dart lib/router/app_router.dart lib/widgets/road_question_widget.dart lib/screens/analysis/analysis_screen.dart lib/services/pdf_report_service.dart test
```

Empty asset directories now have tracked placeholders. The existing
`open_file_macos` plugin warning remains; the prior 21 model-input tests passed despite it. A passing
test suite is not a successful APK/iOS build or real-phone installation.
No product dependencies were added. `.env`, runtime tokens and private clips
are excluded; examples and dependency lockfiles are retained.

Accident entry now retains an owned push case ID or creates a phone-sensor
case for the registered backend device. Video access is case-scoped through
the backend, with no global latest-event or client hardware token fallback.
A phone-only case is not automatically linked to hardware video. Verify real
device mapping/ingestion and phone routing together before acceptance.

`lib/services/auth_service.dart` defines `kApiBaseUrl`, currently
`http://10.0.2.2:8000`, overridden with `--dart-define=API_BASE_URL=<origin>`.
The default addresses the host from its Android emulator only,
not a teammate's host or phone. Agree a reachable private API origin and a
backend-issued reachable storage origin before phone tests. Port 9000 is
MinIO, not a LAW endpoint. No API internet/Tailnet exposure was added here.

### Implemented Flow

Current release adds checked automatic-road UI, null-road first requests,
Mock speed, explicit consent/withdrawal, current insurer data, typed report
notifications, bounded photo/video chat, and reference-only warnings. Deploy
the matching API/worker and migration `0015` together. The existing GPU package
still requires a road; the user will provide an unconditioned inference path.
Automatic report generation is deferred. Neither saved movement text nor
media observations are new trained fault-model inputs.

- Choose an owned case from server history or retain its unconsumed push ID;
  each new manual accident creates a new case, never reuses the last incident.
- New evidence uses photo/video signed upload -> storage PUT -> completion; failures
  stay visible. Existing stored audio remains readable/deletable but is not a chat attachment.
  Additional media does not automatically launch fault-model analysis.
- Chat uses server GET `data.chats` and POST `data.messages`, retains statements,
  and marks mock/unavailable responses. No Groq key or direct LLM call is in Flutter.
- Profile sync separates personal/insurer phone. Case/account deletion shows
  asynchronous acceptance, not instant physical purge. Local PDF exports stay distinct.
- A selected historical report opens that exact version read-only. Reanalysis
  requires the explicit action, not tapping a history row.
- A validated Gangnam environment snapshot is visibly labeled synthetic/mock
  in the report and PDF; it never replaces the case's actual GPS.
- A cloud-case deletion preserves explicitly exported local PDFs; the local PDF
  delete action is separate. Logout and accepted account deletion attempt to
  remove app-owned local video/audio/PDF copies and private settings, not
  unrelated files. Cleanup failure does not reverse logout or server acceptance.
- Analysis uses API 8000, authenticated backend `case_id`, and exact `job_id` polling.
- Road codes: 0 straight, 1 signal, 2 unsignaled, 3 T-junction, 4 highway,
  5 parking, 6 roundabout, 7 roadway/non-roadway.
- Road 1 immediately shows the other car's `left/right/u_turn/straight_other/unknown`.
  Road 6 shows `entering/circulating/lane_change/unknown`. Unknown is zero;
  changing roads clears incompatible answers. Backend constructs model vectors.
- Selection changes submit reanalysis after 300 ms. Previous results are marked
  historical; PDF export waits for the completed report's own inputs.
- Display model-labelled B/A only. No owner/opponent reinterpretation, no 50:50
  fallback. Preserve assumed GPS and unavailable LAW labels.

For the verified integration entry, case identity is mandatory: use the existing `/analysis` GoRouter route with
`context.push('/analysis', extra: caseId)` for an owned backend ID, or resolve
the genuinely selected hardware event with the saved registered
backend device via `GET /api/v1/cases/by-event`. This lookup does not import a
new hardware event. Never synthesize an ID or use a globally latest event.

Read `GET /api/v1/cases/{case_id}/road`, then send:

```http
POST /api/v1/cases/{case_id}/analysis
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{"road":{"place":1,"other_action":"left"},"facts":{},"keywords":[]}
```

HTTP 202 returns `data.job.id`. Poll that exact
`GET /api/v1/cases/{case_id}/jobs/{job_id}` with the owner token. Wait on
queued/running/retrying, stop on failed/dead, and consume `data.report` only
when done. Reject missing/mismatched jobs/reports and malformed response shape.
Never use aggregate case.done or a previous latest report as this request's success.
PUT `/road` also queues reanalysis; do not additionally call it for the same change.
Empty `{}`/`[]` feedback clears old fields; omitted/null fields preserve them.

`data.report.analysis.status` is complete/incomplete/unavailable. Only a real,
complete B/A prediction is displayed. Missing road requires a selection;
GPU input errors can return a done job with null prediction and model.reason,
such as clip_too_short. LAW is unavailable even when MODEL completes. Read
GPS assumptions from provenance or model_input; real-source reports can omit
provenance. API errors are `{error:{code,message},request_id}`: 401 login,
403 owner, 404 missing/deleted case/job, 409 input/deletion conflict, 422 invalid
answer. Do not turn any of these into a fabricated result.

Earlier model-input changes: `lib/services/model_analysis_service.dart`,
`lib/widgets/road_question_widget.dart`, `lib/screens/analysis/analysis_screen.dart`,
`lib/services/pdf_report_service.dart`, plus four tests. The model client is the
source of backend request/polling behavior; the backend builds neural vectors.

### Verification And Phone Checklist

Previous published workflow baseline: 98 Flutter tests passed. Static analysis of the
changed screens/services and all tests found no errors or warnings; three
pre-existing Home `const` info hints remain (`--no-fatal-infos`). This includes real
asynchronous account/case/download race reproductions using temporary files.
Backend revision `1208e7d4` has 631 unit tests run (21 gated skips) and two
separate real PostgreSQL/MinIO checks passed. No live Groq/FCM or phone build
was performed. Missing optional asset-directory and macOS-plugin warnings
remain from the original app.

Prior GPU baseline: 21 app tests, targeted analyzer and actual app API client -> real GPU
-> final reports for left, circulating and unknown inputs. The collector recovered
from 530/1033; a fresh 41.9-second 1080p ADXL345 event passed as well as the earlier
9.958-second assumed-GPS manual video. A read-only synthetic-device import was
used, so production device binding/automatic ingestion remains unverified.
Videos below six seconds are rejected. Preserve real GPS versus assumed GPS markers.

Before phone integration, configure reachable private API/storage addresses
and backend login/device/event mapping. MinIO is Tailnet-only on 9000; do not
rewrite signed URLs or publish storage to the internet. `.env` and secrets are excluded.

1. Log in, register the correct backend device and select an owned case from
   server history; also verify push/sensor entry does not reuse another case.
2. Select road 1 and left; confirm the question appears and a new report arrives.
3. Select road 6 and circulating; confirm the three-channel vector in the
   report, a distinct report version and correct B/A labels.
4. Select unknown; expect zero vector. Change to another road; answer clears.
5. Test missing road, expired login, network failure and old-report/PDF guards.
   Never display 50:50 for null or unavailable. Check narrow phone layout.
6. Confirm assumed GPS on the manual sample, real-source provenance on the
   physical event, LAW unavailable and retained report history on the backend.
7. Upload photo/video, reopen server history/chat, test profile clearing and
   accepted deletion on a test account. Test external LLM failure without fake replies.

The [backend handoff](../backend/handoff.md)
is in this branch, with deeper
[road](../docs/backend/19-road-input.md),
[API](../docs/backend/20-app-contract.md) and
[verification](../docs/backend/23-hardware-app-input.md)
contracts. GPU weights, auth and private origins are delivered
separately; do not copy backend model credentials into the phone.

## 한국어

### 실제 MODEL·LAW 연동 (2026-10-17)

이 절이 아래 과거 LAW 목업·미가용 기록보다 우선한다. 같은 버전의 로컬 API·워커가 실제 Windows GPU MODEL과 LAW를 사용한다. 분석·저장 리포트 화면에서 법률 쟁점·법령·판례·출처·공식 원문 링크를 표시하며 검색도 새 `/api/v1/law/search` 계약을 사용한다. 예전 9000번 LAW API나 임의 법원·날짜·과실 정보로 채우지 않는다.

실제 LAW 제공자이며 상태가 완료/일부 완료일 때만 근거를 표시한다. 알림의 작업 ID는 해당 사건 작업 API로 조회하고 전달된 리포트 ID도 대조하며 결과를 여는 것만으로 재분석하지 않는다. 사용자 검색 조건의 수정·해제를 지원하되 영상에서 확인한 사실로 승격하거나 모델 과실을 바꾸지 않는다. 미가용 결과는 50:50으로 대신하지 않는다.

맥 시뮬레이터는 API 주소를 `http://127.0.0.1:8000`으로 빌드한다. 시작 알림은 실제 사건·작업·리포트 ID를 사용하는 Apple 시뮬레이터 테스트 알림이며 실제 FCM/APNs 발송 검증과는 다르다. LAW는 과거 오프라인 법률 자료를 검색하고 주소·기상·속도는 목업이다. 앱에 알림 서비스 인증값을 넣지 않는다.

현재 iOS 26 Apple Silicon 시뮬레이터가 기존 OCR 라이브러리의 x86 빌드를 설치하지 못해, 이번 로컬 시연용으로만 생성된 네이티브 파일에서 OCR 플러그인 두 개를 제외해 arm64로 빌드한다. 의존성 선언과 실기기 OCR 소스는 유지하며 시연에서는 면허번호를 직접 입력한다. 생성 파일을 다시 만들면 원래 기기 설정으로 돌아간다. 시연용으로 생성된 Podfile 잠금을 전체 실기기용 잠금 파일로 게시하지 않는다. 이번 통합 소스는 로컬 상태이며 별도 커밋·푸시가 필요하다.

현재 고정된 Firebase 알림 라이브러리는 앱 시작 알림을 관찰하므로 UIScene 엔진에서 늦게 등록하면 클릭 이벤트를 받지 못한다. 이번 빌드는 앱 시작 완료 전에 플러그인을 등록하고, 기존 장면 설정을 보존한 채 이름 앞에 `_`를 붙이는 [Flutter 공식 임시 호환 절차](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate#temporarily-disable-uiscene)를 사용한다. 알림 라이브러리 업그레이드와 검증 후 UIScene을 다시 켜야 하며, Xcode 27/iOS 27 SDK로 빌드하기 전에는 반드시 완료해야 한다. 이 설정을 유지하는 동안 Flutter 테스트와 함께 `python3 test/ios_config_test.py`를 실행한다.

시뮬레이터 로그인에는 승인된 이 앱 전용 키체인 그룹만 가진 Xcode 생성 임시 서명을 사용한다. 서명 없는 빌드에 제한 권한을 나중에 직접 붙이지 말고, 임시 시뮬레이터 권한 파일로 Xcode 서명을 켜서 빌드한다. 다른 앱과의 키체인 공유, 운영 서명, 인증 우회, 앱 내 MODEL·LAW 인증값은 추가하지 않았다.

2026-10-17 검증: Flutter 테스트 216개, 네이티브 설정 검사 2개와 arm64 시뮬레이터 빌드가 통과했으며 변경 파일 정적 검사에도 문제가 없었다. 앱 업데이트·재실행 후 로그인이 유지되고, 시뮬레이터 완료 알림을 누르면 정확한 저장 작업·리포트의 실제 MODEL 비율과 LAW 근거 9개가 열린다. 요약 문장·주소·기상·속도는 목업이다. 수집 서버가 미가용이어서 새로 받은 영상이 아닌 보관된 원본 검증 영상을 사용했다. 실기기 FCM 발송과 OCR은 이번 시연의 검증 범위가 아니다.

### 업스트림 추가 기능 (2026-10-17)

`pth888/driveguard-ai` 기본 브랜치의 `a87d415`와 비교해 우리 앱에 없던 기능만 추가했다.

- 수신 영상 아래 `사고 위치 보기`를 펼치면 해당 사건의 PNG 지도·경로·출처·GPS·촬영 시각을 조회한다. 가정 GPS를 구분하고 GPS 없음·지도 생성 중·인증 실패·서버 장애를 표시한다. 사건·계정 변경 시 이전 지도는 지운다. 주소·기상·속도 제공자는 변경하지 않았다.
- 마이페이지에서 `서버 연결`과 `이름만 등록`을 구분한다. 수집 서버 HTTPS 주소와 전방/후방(`violet-dashcam-1`/`violet-dashcam-2`)을 선택하되, 백엔드에 이미 승인된 본인 장치 매핑이 있어야 성공한다. 공개된 장치 ID 입력만으로 소유권을 인정하지 않는다. 실패하면 기존 백엔드 장치 ID를 보존하며 하드웨어 인증값은 휴대폰에 저장하지 않는다.

이 통합 작업 공간의 백엔드 호환 변경도 앱과 함께 배포해야 한다. 이전에 게시한 백엔드 버전만으로 새 API가 제공되지는 않는다.

- `POST /api/v1/devices/link`: 사용자 인증과 `{name, server_url, device_id, position}`을 받는다. 성공 시 백엔드 장치 `id`와 `name`, 수집 연결 `collector`를 반환한다. 수집 장치 ID를 사건 API의 백엔드 ID로 쓰지 않는다. `409 device_not_linked`는 운영자의 소유권 매핑 승인이 먼저 필요하다는 뜻이고 잘못된 주소·전후방·이름은 422다.
- `GET /api/v1/devices/{backend_id}`: 본인 장치 메타데이터를 조회한다. `collector: null`은 연결 미설정·해제 상태이며 인증값은 반환하지 않는다.
- `GET /api/v1/cases/{case_id}/map`: 사용자 인증으로 본인 사건의 `data.map`을 조회한다. 상태·PNG(base64 또는 null)·경로 여부·GPS·촬영 시각·가정 여부·재시도 안내를 반환한다. 삭제 중이거나 삭제된 사건의 지도는 반환하지 않는다.

지도는 백엔드가 승인된 User-Agent와 선택적 읽기용 `COLLECTOR_TOKEN`으로 조회한다. 삭제 인증을 재사용하지 않고, 같은 사건의 표준 파일 경로와 숫자 버전 쿼리만 허용한다. 리다이렉트·2MiB 초과 이미지·4096픽셀 초과 크기를 차단한다. 앱은 임의 원격 URL이나 수집 인증값 대신 검증된 PNG 바이트를 받는다. DB 테이블·영구 지도 복사본·SDK·의존성을 추가하지 않았고 OpenStreetMap 출처를 유지한다. 촬영 시각은 기기 보고값이지 인증된 시각이 아니다.

원본 앱의 직접 수집 서버/LLM 호출·가짜 토큰·오류 시 50:50·로컬 저장만으로 연결 성공 처리하는 코드는 가져오지 않았다. 녹취는 앞서 합의한 추가 증거 범위에 따라 제외 상태를 유지한다. 기존 영상·GPU·도로 질문·동의·참고용 경고는 보존했다.

앱 전체 203개, 백엔드 전체 724개 실행(환경 조건부 24개 스킵)을 확인했고 경로 검증 보강 후 새 백엔드 테스트 7개도 통과했다. 실제 휴대폰·물리 장치 연결 검증과는 구분한다. 실제 지도 조회 시 수집 서버에서 HTTP 530/Cloudflare 1033이 반환돼 서버 복구 뒤 생성 지도를 추가 확인해야 한다. 이번 추가 기능 변경은 커밋·푸시하거나 실행 서비스를 재시작하지 않았다.

### 로컬 피드백 수정 (2026-10-16)

- 동의 체크는 마지막 `동의하고 계속`을 누른 뒤 저장된다. 기기 위치 권한을 허용하는 것만으로 수집 동의가 끝나거나 메인으로 이동하지 않는다.
- 동의 후 보험사·연락처·면허 정보가 부족하면 등록 화면을 연다. 면허번호는 백엔드의 문자열·길이 계약으로 입력받으며 실제 면허 자격 인증을 뜻하지 않는다.
- 일반 앱에서 장치 인증값의 보관·표시·복사를 제거했다. 하드웨어 인증은 유지되며 이름만 등록한 것은 실제 수집 장치 연결이 아니다. 재등록 때 기존 장치를 몰래 해제하지 않는다.
- 안전 체크리스트를 개별 선택할 수 있고, 신고·보험 연락은 확인창 뒤 전화 앱을 연다. 실행 실패는 표시하며 시뮬레이터에서는 실제 통화를 할 수 없다.
- 모든 도로유형에서 차량 거동 설명은 선택이다. 신호·회전교차로의 추가 답변도 선택 및 해제할 수 있으며, 미입력은 null/0벡터로 전달한다.
- 로컬 앱 전체 174개 테스트와 수정 파일 정적 분석을 통과했다. 다시 빌드한 iOS 시뮬레이터에서 수신 원본과 실제 B 30% / A 70% GPU 결과 화면을 확인했으며 실제 휴대폰 검증과는 구분한다. 20fps 영상의 정확 탐색 시 149프레임이 되는 전처리 오류를 수정했고 전처리 18개, 모델 서비스 160개 통과·1개 생략을 확인했다.
- 홈과 영상 대기 화면에 `최신 블랙박스 영상 보기`를 추가했다. 사용자 인증으로 `GET /api/v1/cases/latest-hardware`를 조회해 본인의 삭제 중이 아닌 수집 사건 중 원본이 있는 사건만 선택한다(`data.case` 또는 null). 해당 사건의 영상 단계로 바로 진입하고 분석까지 같은 ID를 유지하며 새 수동 사고에 이전 영상을 몰래 붙이지 않는다.
- 영상 상태에 사건 ID를 포함하고 소유권 확인과 현재 사건 일치 후에만 재생한다. 확인이 느리거나 실패해도 이전 사건의 캐시 영상은 표시하지 않는다.
- 최신 연결 장치 사건 `test_shock_20261015_144010Z_20261015_143940Z`는 로컬 MinIO에 34,082,710바이트·45.4초 원본으로 저장됐다. 전체 다운로드 SHA256이 일치하며 실제 앱 분석 클라이언트로 신호/좌회전·회전교차로/회전 중·신호/미응답(0벡터)·직선의 GPU 리포트를 검증했다. 마지막 직선 시험 입력은 B 30%, A 70%이며 도로는 명시한 시험 선택이지 GPS 자동 추정 성공값이 아니다. LAW는 미가용, 주소·기상·리포트 본문은 목업이다.
- 독립 CUDA 패리티 후 추론 서버를 재시작했다. L1 20/20·최대 유형 오차 3.954e-6, L2 과실·유형 결정 모두 20/20·최소 특징 코사인 0.992787·최대 과실 확률 오차 0.030492다. 모델팀 수정 기준 0.97/0.05를 충족했지만 초기 엄격 기준 0.995/0.02를 충족한 것은 아니다. 학습·가중치는 변경하지 않았고 MinIO는 로컬·테일스케일 내부로 유지한다.

현행 서비스 변경과 설정은 [서비스 업데이트](../docs/backend/25-service-release.md)를 따른다.
자동 도로 체크·미입력 첫 요청·목업 속도·동의와 철회·서버 보험정보·리포트 알림·사진/영상 상담·참고용 경고를 추가한다.
같은 API/worker와 `0015`를 함께 적용한다. 현재 GPU의 도로 필수 제약은 검증된 새 경로가 전달된 뒤 확인하며 자동 리포트 생성은 보류한다.
FCM 제공자 구현과 실제 휴대폰 수신 시험은 구분한다. 거동 자유 서술과 시각 관찰을 학습된 과실 모델의 새 특징으로 설명하지 않는다.

전달 저장소는 CHAEMUNJEONG/blackbox-ai, 브랜치는 GI-DOONG, 앱 위치는 app/다.
기존 NOmodel&law_pipelineUP_backend의 백엔드도 같은 브랜치에 유지한다.
Git은 `GI~DOONG`을 허용하지 않아 하이픈으로 바꿨다. 실제 휴대폰 설치는 미검증이다.
기존 앱 저장소의 쓰기 권한 문제 대신 사용자 요청대로 우리 저장소에 소스 전체를 넣었다.
검증한 구현은 원본 앱의 7b386b8이며 중첩 Git·서브모듈 없이 가져왔다.
Flutter 명령은 저장소 최상위가 아니라 app/에서 실행한다.
8개 도로 토글과 신호교차로·회전교차로의 상대 차량 질문을 구현했다. 선택하면
300ms 후 같은 사건으로 재분석하고 반환된 작업의 리포트를 조회한다. 모름은 0 벡터,
도로 변경 시 기존 답변을 초기화하며 PDF는 완료된 분석 입력만 사용한다.

이전 모델 입력 기준으로 앱 시험 21개·정적 검사와 실제 GPU 재분석을 통과했다.
이번 서버 대화·증거·프로필·이력 변경의 검증 수치와는 구분한다.
이전 공개 앱 변경은 전체 98개 테스트를 통과했다. 당시 변경 화면·서비스·테스트 정적 검사에서
오류·경고는 없고 기존 홈 화면 const 정보 권고 3개만 남아 --no-fatal-infos로 확인했다.
계정·사건 전환과 늦은 다운로드는 임시 파일로 재현했다. 실제 Groq·FCM 호출이나
휴대폰 빌드·설치를 검증한 수치는 아니며 기존 선택 자산·macOS 플러그인 경고는 남아 있다.
GPS 가정값·LAW 미가용·모델 B/A를 유지하며 실패를 50:50으로 만들지 않는다.
수집 서버 복구 후 실제 1080p·41.9초 충격 영상도 새로 받아 검증했다. 시험 장치의
읽기 전용 수입이므로 운영 장치 자동 수집·매핑은 미검증이다. 이전 수동 영상의 GPS
가정값과 실제 센서 출처를 구분한다. 6초 미만은 거부한다. 사설 주소·로그인·장치/사건 매핑은
실기기 연동 전에 맞춰야 한다. MinIO 9000은 테일스케일 내부에서만 사용한다.

이번에 로컬 UUID와 전역 최신 영상 선택을 제거했다. 푸시의 사건 ID를 유지하거나 본인
장치의 휴대폰 충격 사건을 만들고 서버 사건 이력에서 명시적으로 선택한다. 휴대폰 사건이
하드웨어 영상과 자동으로 매칭되는 것은 아니므로 운영 장치·실기기 흐름은 함께 확인한다.
사진·음성 저장, 서버 대화·사건 이력, 차량·보험 프로필, 사건 삭제·회원 탈퇴를 연결했다.
새 수동 사고는 이전 사건을 재사용하지 않으며 이력의 리포트는 선택한 버전을 읽기 전용으로
연다. 재분석은 별도 버튼이다. 강남역 환경값은 화면·PDF에 합성 목업이라고 표시하고 실제
GPS를 대체하지 않는다. 챗봇의 목업 응답도 별도 표시한다.
법령·판례와 주소·기상은 목업이며 실제 챗봇 키는 백엔드에만 둔다. 세부 계약은 위 24번 문서다.
클라우드 사건 삭제와 내보낸 PDF 삭제는 별도다. 로그아웃·탈퇴 접수 시 앱이 만든 로컬
영상·음성·PDF와 개인 설정 정리를 시도하며 다른 파일은 건드리지 않는다. 로컬 정리 실패가
로그아웃이나 서버의 삭제 접수를 취소하지는 않는다. 자유 입력의 개인정보는 완전히
감지하지 못하므로 챗봇·사건 제목에 면허·보험번호 같은 민감정보를 입력하지 않는다.

`auth_service.dart`의 API 주소 10.0.2.2:8000은 서버 컴퓨터의 에뮬레이터 전용이므로
팀원 컴퓨터·휴대폰에서는 접근 가능한 사설 주소를 맞춘다. 저장소 서명 주소를 임의로
수정하거나 API 토큰을 붙이지 않는다. 운영 장치와 선택 이벤트가 먼저 수집되어 있어야 한다.

로그인한 소유자의 토큰으로 도로 조회 → POST analysis → 202의 job.id 조회 →
그 작업의 data.report 순서다. 과거 latest나 case.done을 이번 성공으로 판단하지 않는다.
분석 화면 이동은 기존 /analysis 경로의 extra에 백엔드 case_id를 전달한다.
실패·null·미완료는 비율 없이 표시한다. GPU 422가 done 작업의 unavailable 리포트로
반환될 수 있으며 reason clip_too_short를 확인한다. GPS 가정 여부는 provenance 또는
model_input에 있고 실제 영상은 provenance가 없을 수 있다. PUT road는 별도 중복 호출하지 않는다.

실기기에서는 로그인/장치/사건 매핑, 신호·회전 추가 질문과 새 리포트, 모름/답변 초기화,
통신·인증 오류, 이전 결과와 PDF 차단, 좁은 화면을 위 순서대로 확인한다.
기존 자산 경로·macOS 플러그인 경고는 남아 있다. 이번 테스트가 실제 휴대폰 빌드·설치,
Groq 호출·FCM 수신·물리 삭제 완료를 뜻하지는 않는다. 환경 파일·모델 인증·가중치는
Git과 휴대폰에 넣지 않는다.

## Chat Presentation Update (2026-10-17)

Chat responses and history now include `kind`: `conversation`, `internal`, or
`legacy`. The server assigns IDs and the kind; clients must not infer provenance
from user text for new messages. Render conversation messages unchanged and hide
internal records without deleting them. Existing legacy records have no reliable
source marker, so the app only hides strictly validated reserved road/analysis
payloads; other JSON remains visible. A legacy user message identical to a reserved
payload cannot be distinguished until its provenance is migrated.

Display the submitted question immediately and show a separate waiting indicator
only while its real request is pending. Do not display tool commands, internal
JSON, fabricated processing stages, or private reasoning as conversation. Prevent
duplicate submissions, preserve drafts while busy, and reconcile history after an
ambiguous network failure rather than claiming that the message was not saved.

채팅 응답·기록에 서버가 지정한 `kind`가 추가됩니다. 실제 대화는 그대로 표시하고
내부 기록은 삭제하지 않고 숨깁니다. 과거 기록은 출처 정보가 없어 엄격하게 검증된
도로 선택·추가 정황 형식만 숨기며, 일반 JSON은 표시합니다. 과거에 사용자가 같은
예약 형식을 직접 입력한 경우는 출처를 이관하기 전까지 구분할 수 없습니다.

질문은 즉시 표시하고 실제 요청 중에만 별도 대기 표시를 보여줍니다. 개발 명령,
내부 JSON, 가짜 진행 단계와 비공개 추론을 대화로 표시하지 않습니다. 중복 전송을
막고 대기 중 작성 내용을 유지하며, 통신 오류 시 저장 여부를 단정하지 않습니다.
