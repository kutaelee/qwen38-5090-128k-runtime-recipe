# 벤치마크 데이터

[English](README.md) · [한국어](README.ko.md) · [프로젝트 설명](../README.ko.md)

최신 결과: [NInfer 검증 및 기존 Q5 비교](ninfer-qualification-2026-09-09.ko.md), [실행별 측정 JSON](ninfer-depth-2026-09-09.json).

이 디렉터리는 공개 가능한 집계 결과만 포함합니다. 원본 프롬프트, 소스 저장소, 비공개 로그, 스케줄러 식별자, 세션과 장비별 경로는 제외합니다.

- [런타임 비교](runtime-comparison.ko.md): 기존 성능·정확성·에이전트 결과 해설
- [CSV](runtime-comparison.csv): 프로그램에서 읽을 수 있는 기존 측정값
- [NInfer 검증](ninfer-qualification-2026-09-09.ko.md): 입력 깊이별 성능, 정확성, 최초 실패와 수정 후 재검증
- [장기 에이전트 검증 원문(영문)](long-agent-qualification-2026-08-19.md)
- [NInfer 통합 원문(영문)](ninfer-integration-2026-09-08.md): 시작·Codex 연결 스모크 테스트, 호환성 실패와 수명주기 제약. 처리량 벤치마크가 아닙니다.
- [측정 방법(영문)](../docs/methodology.md)

미측정 값은 CSV에서 빈 필드로 표시하며 추정값으로 대체하지 않습니다. `tok/s`는 초당 생성 토큰 수, TTFT는 첫 토큰까지 걸린 시간, wall time은 실제 경과 시간입니다. 디코딩 속도와 전체 에이전트 작업 완료 속도를 구분해서 읽어야 합니다.
