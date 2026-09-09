# RTX 5090에서 실행하는 Qwen3.8-27B — 128K 멀티 런타임 에이전트 구성 가이드

[English](README.md) · [한국어](README.ko.md)

RTX 5090 한 대에서 Qwen3.8-27B를 실행하기 위한 재현 가능한 추론 설정, 벤치마크, 작업별 런타임 선택 가이드입니다. **모델 가중치를 수정하거나 배포하는 저장소가 아닙니다.**

Q5_K_M + MTP3는 100K 이상의 자율 코딩 실행에서 평균 약 **109.5 tok/s**, 추측 토큰 수락률 **89.6%**를 기록했습니다. 다만 여러 시드에서 동일한 조건으로 측정한 전체 작업 소요 시간이 없어, 실제 에이전트 작업 속도의 최종 순위는 확정하지 않았습니다.

[한국어 벤치마크](benchmarks/README.ko.md) · [최신 NInfer 검증](benchmarks/ninfer-qualification-2026-09-09.ko.md) · [재현 절차(영문)](docs/reproducibility.md) · [Hugging Face 소개](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe)

이 문서는 한국어 설명과 주요 결과를 정리한 안내입니다. 전체 구성 식별자와 상세 운영 절차는 [영문 README](README.md) 및 연결된 원문을 함께 확인하세요.

## 구성 개요

32 GB RTX 5090 한 대에서 생성 런타임을 **하나씩** 실행합니다. 작업 라우터는 자신이 관리하는 이전 런타임을 종료하고 포트와 VRAM 해제를 확인한 뒤, 로컬 루프백 주소에서 선택한 백엔드를 시작합니다.

| 용도 | 런타임 | 현재 상태 |
| --- | --- | --- |
| 기본 단일 에이전트 작업 | llama.cpp + Q5_K_M + Q8_0 K/V + MTP3 | 기존 측정 및 에이전트 검증을 갖춘 기본값 |
| 명시적으로 선택하는 추가 검증 | NInfer + NVFP4 + FP8 KV + MTP3 | 후보 단계, 전체 자율 작업 검증 미완료 |
| 서빙·동시 요청 처리 용도 | SGLang + NVFP4 + FP8 E4M3 KV + FlashInfer, MTP 끔 | 서빙 기준 구성 |

**디코딩 속도(tok/s)는 에이전트의 작업 완료 처리량과 다릅니다.** 작업별 적합성을 구분한 결과이며, 어느 모델 파일이나 런타임이 모든 작업에서 우수하다는 의미는 아닙니다. 공개 측정 환경의 동시 요청 수는 1입니다.

## 측정 환경과 런타임

| 항목 | 구성 |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 보고된 메모리 32,607 MiB |
| 드라이버 | 610.74 |
| 호스트 | Windows; NInfer는 WSL2/Linux, SGLang은 WSL2/Docker, llama.cpp는 네이티브 Windows CUDA |
| 동시 실행 | 생성 런타임 1개, 요청 1개, GPU 1개 |

### 기본값: llama.cpp Q5 + MTP3

- 모델: `bartowski/Qwen3.8-27B-GGUF`, 파일 `Qwen3.8-27B-Q5_K_M.gguf`
- llama.cpp 빌드 10435, 커밋 `9e40df63ba151d771d8b247ac4011cf203337e99`
- 서버 컨텍스트 131,072토큰, K/V 캐시 모두 Q8_0
- Flash Attention 사용, 66/66 레이어 GPU 적재, CPU 폴백 0
- `parallel=1`, `batch=2048`, `ubatch=512`, 비전 끔
- MTP3: `--spec-type draft-mtp --spec-draft-n-max 3`

설정 예시: [llamacpp-q5-mtp3-128k.example.ps1](configs/llamacpp-q5-mtp3-128k.example.ps1).

### 검증 후보: NInfer NVFP4 + MTP3

- 런타임: `Neroued/ninfer`, 고정 리비전 `a16b6442856620b7e4856acb25215acbf7e3c750`
- 모델: `neroued/Qwen3.8-27B-nvfp4-NInfer`, 파일 `qwen3_8_27b_nvfp4.ninfer`
- Linux/WSL2, RTX 5090 (`sm_120a`), CUDA Toolkit 13.1 이상에서 소스 빌드
- OpenAI 호환 엔드포인트: `127.0.0.1:8083`
- NVFP4 가중치, FP8 KV, MTP3, 최적화된 제안 헤드, 동시 요청 1
- 런타임 컨텍스트와 KV 용량 240,000토큰
- Qwen Code 운영 한도는 기존 120,000토큰 유지, 자동 압축 기준 0.7 및 thinking 비활성화 정책 유지

설정 예시: [ninfer-nvfp4-mtp3.example.sh](configs/ninfer-nvfp4-mtp3.example.sh). **240K는 설정 용량이며, 160K–240K 작업을 검증했다는 뜻이 아닙니다.**

### 서빙 기준: SGLang NVFP4

- 모델: `RadixArk/Qwen3.8-27B-NVFP4`
- SGLang 패키지: `0.0.0.dev0+qwen38.27b.g561c8f3`
- 서버 컨텍스트 131,072토큰, FP8 E4M3 KV 풀 약 148,997토큰
- FlashInfer 사용, MTP 끔, CPU 레이어 오프로딩 0
- `max-running-requests=1`, `max-mamba-cache-size=5`

설정 예시: [sglang-nvfp4-128k.example.sh](configs/sglang-nvfp4-128k.example.sh).

## 벤치마크 요약

아래 값은 디코딩 속도이며 단위는 tok/s입니다. NInfer는 2026-09-09 측정, Q5와 SGLang은 기존 측정입니다. **같은 시점의 A/B 실험이 아닙니다.**

| 런타임 | 짧은 입력 | 32K 표기 | 80K 표기 | 114K 표기 |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | 약 69.3 | 미측정 | 약 60.8 | 미측정 |
| Q5_K_M + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |
| NInfer NVFP4 + MTP3 | 222.0 | 190.6 | 176.9 | 169.8 |

32K/80K/114K는 기존 비교 표기입니다. NInfer 실제 프롬프트는 38,717 / 83,917 / 113,956토큰입니다. 짧은 입력도 Q5와 길이가 달라 동일 프롬프트의 속도 향상률로 해석할 수 없습니다. 미측정 값을 추정해 채우지 않았습니다.

Q5의 2026-08-19 자율 코딩 실행에서는 평균 109.51 tok/s, 최대 컨텍스트 106,829토큰, MTP 수락률 89.61%를 관측했습니다. 테스트 하니스 정리 문제를 수정한 뒤 실행 후 정식 검증에서 타입 검사·린트·빌드와 `vitest` 12/12가 통과했습니다. 비교 가능한 전체 작업 소요 시간은 수집하지 않았습니다.

NInfer는 최초 94K Codex 작업에서 호환성 오류로 실패했습니다. 어댑터 수정 후 같은 제한된 읽기·수정·테스트 작업은 33.409초, 테스트 3/3으로 통과했지만, 전체 자율 에이전트 검증을 대체하지 않습니다. **Q5를 기본값으로 유지합니다.**

상세 수치·표본 수·실패 기록: [기존 런타임 비교](benchmarks/runtime-comparison.ko.md), [NInfer 검증](benchmarks/ninfer-qualification-2026-09-09.ko.md).

## 라우팅과 재현

공개 [라우터 예시](configs/local-model-router.example.json)는 데이터 형식의 명세이며 설치된 제어기가 아닙니다.

1. 작업을 분류합니다. 단일 에이전트 기본값은 Q5이며 NInfer는 검증 목적으로 명시적으로 선택합니다.
2. 라우터 소유 런타임만 종료하고 포트와 VRAM 해제를 확인합니다.
3. 장비의 GPU 스케줄러를 통해 선택한 런타임 하나를 시작합니다.
4. `/v1/models`의 모델 ID를 확인합니다. 포트나 모델이 일치하지 않으면 실행을 중단합니다.
5. Qwen Code에 작업별 설정과 외부 의미적 진행 감시를 적용합니다. 원문 검증은 `skipLoopDetection: true`를 사용했습니다.
6. 변경 내역과 통과 기준을 별도로 검증합니다.

모델은 업스트림에서 직접 받아 정확한 리비전과 해시를 확인하세요. `configs/`의 일반화된 경로를 환경에 맞추되 루프백 바인딩을 유지하고, `scripts/healthcheck.example.ps1`로 상태를 확인합니다. 새 측정에서는 처리량보다 정확성을 먼저 검증하고, 제한된 코딩과 장기 자율 작업을 나누어 평가합니다.

자세한 절차: [재현 가이드(영문)](docs/reproducibility.md), [라우팅 가이드(영문)](docs/agent-routing.md).

## 한계와 라이선스

- 하드웨어 표본은 RTX 5090 시스템 한 대입니다. 여러 시드에 걸친 통계적 모델 품질 평가가 아닙니다.
- Q5 재검증의 비교 가능한 전체 소요 시간과 NInfer의 전체 자율 작업 검증은 없습니다.
- 검증에 사용한 비공개 의미적 진행 감시 래퍼 자체는 공개하지 않았습니다. 동등한 제어기 구현을 위한 설정·정책·중단 조건을 제공합니다.
- 런타임별 입력 깊이와 측정 조건이 완전히 일치하지 않습니다. 드라이버·커널·모델 및 에이전트 버전에 따라 결과가 달라질 수 있습니다.
- 비전 경로는 검증하지 않았습니다.

저장소의 구성 가이드, 문서, 소규모 검증 스크립트와 도표는 MIT 라이선스입니다. 모델과 업스트림 런타임에는 각각의 라이선스가 적용됩니다. 다운로드할 정확한 리비전의 라이선스와 모델 카드를 확인하세요. [업스트림 라이선스 기록(영문)](docs/upstream-licenses.md)과 [상세 한계(영문)](docs/limitations.md)를 참고하세요.
