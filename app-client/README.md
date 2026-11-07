# DriveGuard App

## English

Flutter app delivered together with the backend on `REAL_MOCKUP`.
Backend sources remain at the repository root; mobile sources live in `app/`.
Use the backend source from the same commit for matching contracts.
This is a normal directory, not a Git submodule. Source: `pth888/driveguard-ai`
base `92fbec0a`, with model-input changes from `7b386b8`.

From the Blackbox repository root:

```bash
cd app
flutter pub get
flutter test
flutter run --dart-define=API_BASE_URL=https://<private-api-host>
```

Use a compatible Flutter/Dart toolchain; verified with Flutter 3.47.7 and
Dart 3.13.5. Follow [App Handoff](handoff.md) and [Backend Handoff](../backend/handoff.md)
before connecting a phone. Tests passing does not certify APK/iOS builds.

The default API origin in `lib/services/auth_service.dart` is emulator-only
`http://10.0.2.2:8000`; configure `API_BASE_URL` with a reachable private origin for other computers
or phones. MinIO 9000 is storage, not LAW. Real model and LAW analysis use
separate configured inference services. Chat supports Gemini or Groq; current
weather supports Open-Meteo, and road/address estimation supports Kakao Local.
These providers do not enable themselves. See the root [architecture](../diagram.md).

Implemented: eight road choices, signal/roundabout other-car questions, exact
backend job/report polling, canonical B/A values with friendly display labels, unavailable states and safe
PDF export. Owned case entry, photo/audio evidence, server history, chat,
profiles, consent and deletion are connected. Notifications route to the
accident countdown with the owned case ID. FCM registration and optional server
delivery are implemented; simulator notification injection is not physical-phone
FCM certification. Collector sharing remains explicitly configured and does not
grant arbitrary access to another user's private case.

No `.env`, server credentials, signing keys, build directories, SDK caches or
nested `.git` are included. Existing Firebase client configuration belongs to
the original app project; it is not a Firebase Admin service-account key.
Coordinate app project/platform setup with the app owner. The imported tree
retains the original optional macOS-plugin warning. Empty declared asset folders
are tracked. The standard Android Gradle wrapper is included.

Run `flutter pub get` before iOS dependency resolution. Do not reuse simulator
generated plugin registrants or an OCR-excluding local Pod lock for physical
devices. Resolve Pods on the target machine; ML Kit requires a supported physical
device/toolchain and may prevent a full arm64 Simulator build. The previously
shown Simulator used local generated-file adjustments, not a portable release
build. Signing/entitlements and real-device acceptance must be checked separately.

## 한국어

우리 blackbox-ai 저장소 REAL_MOCKUP 브랜치의 app/에 최신 앱 소스를 넣었다.
백엔드는 기존 위치에 유지하며 서브모듈이 아니다. 위 명령은 app/에서 실행한다.
앱·백엔드 핸드오프를 먼저 읽고 휴대폰용 사설 API/저장소 주소와 인증·장치 매핑을 맞춘다.
실제 환경 파일·서버 인증·서명키·빌드/캐시 파일은 제외했다.

8개 도로·추가 질문·모델 재분석·작업별 리포트·PDF와 사건 진입·사진/음성·서버 이력·
대화·프로필·삭제를 연결했다. 로컬 UUID·전역 최신 영상 선택은 제거했다.
실제 모델·LAW 서비스와 Gemini/Groq 상담, Open-Meteo 현재 기상, Kakao 도로 추정은
설정 후 사용할 수 있다. 알림은 소유한 사건의 사고 카운트다운으로 연결하며 FCM 실제
발송 경로도 구현했다. 시뮬레이터 주입 알림과 실기기 FCM 검증은 구분한다.

Android 표준 Gradle 실행 파일을 포함했다. iOS는 먼저 flutter pub get을 실행하고
대상 컴퓨터에서 Pods를 해결한다. 시뮬레이터에서 사용한 로컬 생성 파일·OCR 제외
Pod 잠금 파일은 배포 설정으로 재사용하지 않는다. ML Kit의 기기·도구 지원 제한으로
전체 arm64 시뮬레이터 빌드가 막힐 수 있으며 실기기 서명·권한·설치는 별도 검증한다.
API_BASE_URL과 접근 가능한 저장소 주소를 설정하고 handoff.md를 따른다.

## Analysis-screen handoff and credential review

The analysis report screen previously ended with the reanalysis action only. Road
selection can start a reanalysis automatically, but a completed report remained
on that same screen without an explicit completion path. The screen now exposes
a completion action after a report is available: it returns to the prior screen
when opened from a case video, or opens the incident-video list when there is
no prior route. Reanalysis remains available and its existing bounded job poll
and timeout recovery behavior are unchanged.

Credential review found no backend/API-provider secrets, passwords, private-key
blocks, signing credentials, or environment files in `app-client/`. The existing
Firebase configuration is client-side app configuration used by the original
app for Firebase initialization and push notifications; it is not a Firebase
Admin/service-account credential. Treat its client API key as public, restrict
it to the intended Firebase APIs and app identifiers in the provider console,
and never reuse it as a server credential. `codemagic.yaml` contains the public
API origin, not a secret. Re-run the repository secret scan before publishing
changes or adding build configuration.

### 한국어: 분석 화면에서 다음 단계로 이동

기존 분석 화면은 보고서 표시와 재분석을 같은 화면에서 처리하고, 보고서가
완료된 뒤 이동할 명시적 완료 동작이 없었다. 도로 유형 선택은 자동 재분석을
시작하므로 사용자는 분석이 끝난 뒤에도 화면이 그대로여서 멈춘 것으로 느낄 수
있었다. 보고서가 준비되면 `분석 완료하고 돌아가기`가 표시된다. 사건 영상에서
열었으면 이전 화면으로 돌아가고, 이전 화면이 없으면 사고 영상 기록으로 이동한다.
분석 작업은 최대 2분간 확인하며 시간 초과 시 작업 ID를 유지해 결과를 다시
확인할 수 있다. 이번 변경은 이동 경로를 명확하게 하며 서버 분석 실패 자체를
해결했다고 주장하지 않는다. 실제 분석 실패는 화면의 오류 메시지와 서버 작업
상태를 함께 확인해야 한다.

### 한국어: 자격 증명 점검

앱 경로에서 백엔드·외부 AI 서비스 비밀키, 비밀번호, 개인키/서명 자격 증명,
`.env` 파일은 발견되지 않았다. Firebase 설정은 푸시 알림 초기화에 쓰이는
클라이언트 설정이며 Admin 서비스 계정 키가 아니다. 클라이언트 Firebase API 키는
비밀값으로 취급하지 않되 Firebase 콘솔에서 필요한 API와 앱 식별자로 제한해야 한다.
`codemagic.yaml`의 API 주소는 공개 주소이며 인증 비밀정보가 아니다.
