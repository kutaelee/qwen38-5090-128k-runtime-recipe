# RTX 5090에서 실행하는 Qwen3.8-27B — 128K 멀티 런타임 에이전트 구성 가이드

[English](README.md) · [한국어](README.ko.md)

RTX 5090 한 대에서 Qwen3.8-27B를 실행하기 위한 재현 가능한 추론 설정, 벤치마크, 작업별 런타임 선택 가이드입니다. **모델 가중치를 수정하거나 배포하는 저장소가 아닙니다.**

NInfer NVFP4 + FP8 KV + MTP3는 depth 측정에서 약 38.7K **190.6 tok/s**, 83.9K **176.9 tok/s**, 114K **169.8 tok/s**를 기록했습니다. 2026-09-16 실제 장기 에이전트 작업의 진행 중 스냅샷에서는 **101개 완료 요청, 96,241 output tokens, 132.23 tok/s aggregate decode, MTP 수락률 51.71%**를 관측했습니다. NInfer 장기 작업은 이전 로컬 사용에서도 정상 완료된 사례가 있습니다.

Q5_K_M + MTP3는 완료된 100K+ 자율 코딩 실행에서 평균 약 **109.5 tok/s**, 추측 토큰 수락률 **89.6%**를 기록했고, 완료 후 acceptance 묶음이 저장소에 가장 완전하게 남아 있어 보수적 기본값으로 유지합니다. 이는 NInfer가 장기 작업을 완료하지 못한다는 의미가 아니라, 현재 공개된 증거 보존 수준이 다르기 때문입니다.

[한국어 벤치마크](benchmarks/README.ko.md) · [NInfer 실시간 장기 계측](benchmarks/ninfer-long-agent-live-2026-09-16.md) · [NInfer depth/Codex 검증](benchmarks/ninfer-qualification-2026-09-09.ko.md) · [재현 절차(영문)](docs/reproducibility.md) · [Hugging Face 소개](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe)

이 문서는 한국어 설명과 주요 결과를 정리한 안내입니다. 전체 구성 식별자와 상세 운영 절차는 [영문 README](README.md) 및 연결된 원문을 함께 확인하세요.

## 구성 개요

32 GB RTX 5090 한 대에서 생성 런타임을 **하나씩** 실행합니다. 작업 라우터는 자신이 관리하는 이전 런타임을 종료하고 포트와 VRAM 해제를 확인한 뒤, 로컬 루프백 주소에서 선택한 백엔드를 시작합니다.

| 용도 | 런타임 | 현재 상태 |
| --- | --- | --- |
| 빠른 단일 에이전트 / 장기 실사용 | NInfer + NVFP4 + FP8 KV + MTP3 | depth 기준 가장 빠른 측정값, bounded 94K Codex 통과, 과거 장기 작업 성공, 현재 계측 장기 실행 보존 중 |
| 보수적 기본 단일 에이전트 | llama.cpp + Q5_K_M + Q8_0 K/V + MTP3 | 완료된 장기 자율 작업의 acceptance 증거가 가장 완전하게 보존된 기본값 |
| 서빙·동시 요청 처리 용도 | SGLang + NVFP4 + FP8 E4M3 KV + FlashInfer, MTP 끔 | 서빙 기준 구성 |

**디코딩 속도(tok/s)는 에이전트의 작업 완료 처리량과 다릅니다.** 작업별 적합성을 구분한 결과이며, 어느 모델 파일이나 런타임이 모든 작업에서 우수하다는 의미는 아닙니다. 공개 측정 환경의 동시 요청 수는 1입니다.

## 측정 환경과 런타임

| 항목 | 구성 |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 보고된 메모리 32,607 MiB |
| 드라이버 | 610.74 |
| 호스트 | Windows; NInfer는 WSL2/Linux, SGLang은 WSL2/Docker, llama.cpp는 네이티브 Windows CUDA |
| 동시 실행 | 생성 런타임 1개, 요청 1개, GPU 1개 |

### NInfer NVFP4 + MTP3

- 런타임: `Neroued/ninfer`, 고정 리비전 `a16b6442856620b7e4856acb25215acbf7e3c750`
- 모델: `neroued/Qwen3.8-27B-nvfp4-NInfer`, 파일 `qwen3_8_27b_nvfp4.ninfer`
- Linux/WSL2, RTX 5090 (`sm_120a`), CUDA Toolkit 13.1 이상에서 소스 빌드
- OpenAI 호환 엔드포인트: `127.0.0.1:8083`
- NVFP4 가중치, FP8 KV, MTP3, 최적화된 제안 헤드, 동시 요청 1
- 런타임 컨텍스트와 KV 용량 240,000토큰
- 문서화된 Qwen Code 운영 한도는 120,000토큰, 자동 압축 기준 0.7 및 thinking 비활성화 정책 유지

설정 예시: [ninfer-nvfp4-mtp3.example.sh](configs/ninfer-nvfp4-mtp3.example.sh). **240K는 설정 용량이며, 9월 9일 보존 depth suite에서 160K–240K 실제 작업을 수행했다는 뜻은 아닙니다.**

### 보수적 기본값: llama.cpp Q5 + MTP3

- 모델: `bartowski/Qwen3.8-27B-GGUF`, 파일 `Qwen3.8-27B-Q5_K_M.gguf`
- llama.cpp 빌드 10435, 커밋 `9e40df63ba151d771d8b247ac4011cf203337e99`
- 서버 컨텍스트 131,072토큰, K/V 캐시 모두 Q8_0
- Flash Attention 사용, 66/66 레이어 GPU 적재, CPU 폴백 0
- `parallel=1`, `batch=2048`, `ubatch=512`, 비전 끔
- MTP3: `--spec-type draft-mtp --spec-draft-n-max 3`

설정 예시: [llamacpp-q5-mtp3-128k.example.ps1](configs/llamacpp-q5-mtp3-128k.example.ps1).

### 서빙 기준: SGLang NVFP4

- 모델: `RadixArk/Qwen3.8-27B-NVFP4`
- SGLang 패키지: `0.0.0.dev0+qwen38.27b.g561c8f3`
- 서버 컨텍스트 131,072토큰, FP8 E4M3 KV 풀 약 148,997토큰
- FlashInfer 사용, MTP 끔, CPU 레이어 오프로딩 0
- `max-running-requests=1`, `max-mamba-cache-size=5`

설정 예시: [sglang-nvfp4-128k.example.sh](configs/sglang-nvfp4-128k.example.sh).

## 벤치마크 요약

아래 depth 값은 디코딩 속도이며 단위는 tok/s입니다. NInfer는 2026-09-09 측정, Q5와 SGLang은 기존 측정입니다. **같은 시점의 A/B 실험이 아닙니다.**

| 런타임 | 짧은 입력 | 32K 표기 | 80K 표기 | 114K 표기 |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | 약 69.3 | 미측정 | 약 60.8 | 미측정 |
| Q5_K_M + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |
| NInfer NVFP4 + MTP3 | **222.0** | **190.6** | **176.9** | **169.8** |

32K/80K/114K는 기존 비교 표기입니다. NInfer 실제 프롬프트는 38,717 / 83,917 / 113,956토큰입니다. 짧은 입력도 Q5와 길이가 달라 동일 프롬프트의 속도 향상률로 해석할 수 없습니다. 미측정 값을 추정해 채우지 않았습니다.

### NInfer 실제 장기 에이전트 스냅샷 — 2026-09-16

진행 중이던 실제 장기 작업에서 다음 값을 관측했습니다.

| 지표 | 값 |
| --- | ---: |
| 완료 요청 | **101** |
| 생성 output tokens | **96,241** |
| Aggregate decode | **132.23 tok/s** |
| 요청별 decode 평균 | **140.59 tok/s** |
| 요청별 decode 중앙값 | **136.2 tok/s** |
| 전체 MTP 수락률 | **51.71%** |
| 표시된 로그에서 확인한 prompt depth | **최소 88,250토큰** |

AggregateTPS는 총 output tokens를 각 요청의 `output/decode_tps`로 추정한 전체 decode time으로 나눈 출력 토큰 가중값입니다. 과거 Q5 장기 실행의 109.51 tok/s보다 수치상 약 20.7% 높지만, workload와 하니스가 동일한 A/B가 아니므로 런타임 자체가 20.7% 빠르다고 단정하지 않습니다.

NInfer는 이전 장기 작업에서도 정상 완료됐습니다. 다만 이전 성공 실행의 정량 telemetry bundle이 이 저장소에 남아 있지 않아 해당 실행에 수치를 소급해 붙이지 않았습니다. 현재 계측 실행 역시 이 스냅샷 시점에는 진행 중이므로 최종 task acceptance는 별도로 갱신해야 합니다.

상세: [NInfer 실시간 장기 계측](benchmarks/ninfer-long-agent-live-2026-09-16.md).

### 기존 완료 실행

Q5의 2026-08-19 자율 코딩 실행에서는 평균 109.51 tok/s, 최대 컨텍스트 106,829토큰, MTP 수락률 89.61%를 관측했습니다. 테스트 하니스 정리 문제를 수정한 뒤 실행 후 정식 검증에서 타입 검사·린트·빌드와 `vitest` 12/12가 통과했습니다. 비교 가능한 전체 작업 소요 시간은 수집하지 않았습니다.

NInfer는 최초 94K Codex 작업에서 호환성 오류로 실패했습니다. 어댑터 수정 후 같은 제한된 읽기·수정·테스트 작업은 33.409초, 테스트 3/3으로 통과했습니다.

상세 수치·표본 수·실패 기록: [런타임 비교](benchmarks/runtime-comparison.ko.md), [NInfer 검증](benchmarks/ninfer-qualification-2026-09-09.ko.md).

## 라우팅과 재현

공개 [라우터 예시](configs/local-model-router.example.json)는 데이터 형식의 명세이며 설치된 제어기가 아닙니다.

1. 작업을 분류합니다. Q5는 완료된 acceptance 증거를 기준으로 보수적 기본값이고, NInfer는 더 높은 실측 decode 성능이 필요한 단일 에이전트/장기 작업 경로로 선택할 수 있습니다.
2. 라우터 소유 런타임만 종료하고 포트와 VRAM 해제를 확인합니다.
3. 장비의 GPU 스케줄러를 통해 선택한 런타임 하나를 시작합니다.
4. `/v1/models`의 모델 ID를 확인합니다. 포트나 모델이 일치하지 않으면 실행을 중단합니다.
5. 선택한 런타임에 맞는 작업별 에이전트/하니스 설정을 적용합니다.
6. 변경 내역과 통과 기준을 별도로 검증합니다.

모델은 업스트림에서 직접 받아 정확한 리비전과 해시를 확인하세요. `configs/`의 일반화된 경로를 환경에 맞추되 루프백 바인딩을 유지하고, `scripts/healthcheck.example.ps1`로 상태를 확인합니다. 새 측정에서는 처리량보다 정확성을 먼저 검증하고, 제한된 코딩과 장기 에이전트 작업을 나누어 평가합니다.

자세한 절차: [재현 가이드(영문)](docs/reproducibility.md), [라우팅 가이드(영문)](docs/agent-routing.md).

## 한계와 라이선스

- 하드웨어 표본은 RTX 5090 시스템 한 대입니다. 여러 시드에 걸친 통계적 모델 품질 평가가 아닙니다.
- 장기 실행끼리 workload·하니스·요청 분포가 동일한 동시 A/B가 아닙니다.
- Q5 재검증의 비교 가능한 전체 소요 시간은 수집하지 않았습니다.
- 이전 NInfer 장기 작업은 성공했지만 비교 가능한 정량 telemetry bundle은 보존돼 있지 않습니다. 2026-09-16 계측 실행은 공개된 스냅샷 시점에 아직 진행 중입니다.
- 런타임별 입력 깊이와 측정 조건이 완전히 일치하지 않습니다. 드라이버·커널·모델·에이전트 버전·하니스·tool-call 패턴·MTP 수락률에 따라 결과가 달라질 수 있습니다.
- NInfer의 240K는 설정 용량이며, 보존된 9월 9일 depth suite에서 160K–240K 작업을 검증했다는 뜻이 아닙니다.
- 비전 경로는 검증하지 않았습니다.

저장소의 구성 가이드, 문서, 소규모 검증 스크립트와 도표는 MIT 라이선스입니다. 모델과 업스트림 런타임에는 각각의 라이선스가 적용됩니다. 다운로드할 정확한 리비전의 라이선스와 모델 카드를 확인하세요. [업스트림 라이선스 기록(영문)](docs/upstream-licenses.md)과 [상세 한계(영문)](docs/limitations.md)를 참고하세요.