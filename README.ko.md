# RTX 5090 한 장으로 Qwen3.8-27B 돌리기

[English](README.md) · [한국어](README.ko.md)

32 GB RTX 5090 한 장에서 Qwen3.8-27B를 실제로 굴리면서 정리한 설정과 측정값입니다.

이 저장소에서는 용도에 따라 세 가지 런타임을 나눠 씁니다.

- **NInfer + NVFP4 + FP8 KV + MTP3**: 빠른 단일 에이전트 작업
- **llama.cpp + Q5_K_M + MTP3**: 검증 기록이 더 잘 남아 있는 보수적인 대안
- **SGLang + NVFP4**: 서빙·동시 요청 실험용

모델 가중치를 수정하거나 재배포하는 저장소는 아닙니다. 실제로 사용한 런타임 설정, 정확한 리비전, 벤치마크, 실패 사례를 한곳에 모아 재현하기 쉽게 만드는 것이 목적입니다.

[벤치마크](benchmarks/runtime-comparison.ko.md) · [NInfer 장기 에이전트 계측](benchmarks/ninfer-long-agent-live-2026-09-16.md) · [NInfer 검증 기록](benchmarks/ninfer-qualification-2026-09-09.ko.md) · [재현 가이드](docs/reproducibility.md) · [Hugging Face 소개](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe)

![Workload-aware runtime routing](assets/architecture.svg)

## 먼저 결과부터

내 RTX 5090에서 NInfer + NVFP4 + FP8 KV + MTP3로 측정한 값입니다.

| 실제 프롬프트 토큰 | 디코드 속도 | Draft 수락률 |
| ---: | ---: | ---: |
| 54 | 222.0 tok/s | 83.92% |
| 38,717 | 190.6 tok/s | 75.55% |
| 83,917 | 176.9 tok/s | 73.84% |
| 113,956 | 169.8 tok/s | 75.82% |

별도로 실제 장기 코딩 에이전트 작업을 돌렸을 때, 진행 중 스냅샷은 다음까지 올라갔습니다.

- 완료 요청 101개
- 생성 output tokens 96,241
- output-token 가중 aggregate decode 132.23 tok/s
- 요청별 decode 평균 140.59 tok/s
- 요청별 decode 중앙값 136.2 tok/s
- 전체 MTP 수락률 51.71%
- 보존된 로그 구간에서 확인된 프롬프트 최소 88,250토큰

다만 이 수치를 Q5와의 순수한 런타임 성능 차이로 보면 안 됩니다. Q5와 NInfer는 같은 시점, 같은 워크로드로 돌린 정식 A/B가 아닙니다.

## 왜 런타임을 세 개로 나눴나

처음에는 하나의 런타임으로 전부 처리하고 싶었는데, 실제로 써보니 용도별로 안정적인 구성을 몇 개 유지하고 GPU에는 한 번에 하나만 올리는 방식이 더 편했습니다.

| 용도 | 런타임 | 유지하는 이유 |
| --- | --- | --- |
| 빠른 단일 에이전트 / 장기 코딩 | NInfer + NVFP4 + FP8 KV + MTP3 | 이 장비에서 직접 측정한 단일 에이전트 decode 성능이 가장 좋았고, 100K+ 프롬프트에서도 속도 저하가 비교적 작았음 |
| 보수적인 기본값 | llama.cpp + Q5_K_M + Q8_0 K/V + MTP3 | 완료된 장기 에이전트 작업과 최종 검증 기록이 현재 저장소에 가장 잘 남아 있음 |
| 서빙 / 동시 요청 | SGLang + NVFP4 + FP8 KV | FlashInfer와 chunked prefill을 사용하는 서빙 기준 구성 |

GPU에는 생성 런타임을 동시에 여러 개 상주시키지 않습니다. 라우터 예시는 기존 런타임을 종료한 뒤 포트와 VRAM이 풀렸는지 확인하고 다음 백엔드를 올리는 방식입니다.

여기서 가장 중요한 점은 하나입니다.

> **decode tok/s와 실제 에이전트 작업 처리량은 같은 값이 아닙니다.**

벤치마크가 빨라도 tool call, prefill, cache miss, 하니스 동작, 잘못된 에이전트 경로 때문에 실제 작업은 더 느릴 수 있습니다. 그래서 이 저장소에는 단순 depth 벤치와 실제 에이전트 실행 기록을 같이 남깁니다.

## 테스트 환경

| 항목 | 구성 |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB 보고 |
| 드라이버 | 610.74 |
| 호스트 | Windows |
| NInfer | WSL2 / Linux |
| SGLang | WSL2 / Docker |
| llama.cpp | Windows 네이티브 CUDA |
| 공개 벤치 동시성 | 요청 1개, 생성 런타임 1개, GPU 1개 |

## NInfer: NVFP4 + FP8 KV + MTP3

현재 이 장비에서 직접 측정한 단일 에이전트 경로 중 가장 빠른 구성입니다.

### 사용한 구성

- 런타임: [`Neroued/ninfer`](https://github.com/Neroued/ninfer)
- 고정 런타임 리비전: [`a16b6442…c750`](https://github.com/Neroued/ninfer/commit/a16b6442856620b7e4856acb25215acbf7e3c750)
- 모델: [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer)
- 테스트한 모델 리비전: [`11dbbbbb…31be`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer/tree/11dbbbbbc33db198afe2f02c9232c771ff7031be)
- 파일: `qwen3_8_27b_nvfp4.ninfer`
- SHA-256: `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c`
- Linux / WSL2
- CUDA Toolkit 13.1 이상
- OpenAI 호환 엔드포인트: `127.0.0.1:8083`
- NVFP4 weights
- FP8 KV cache
- MTP3
- 동시 요청 1
- 런타임/KV 설정 용량 240,000토큰

Qwen Code에서는 여전히 **120,000토큰을 운영 상한**으로 두고 기존 0.7 auto-compaction 정책을 사용합니다. 위의 240K는 런타임이 잡을 수 있는 용량이지, 240K까지 에이전트 품질을 검증했다는 뜻은 아닙니다.

설정 예시: [`configs/ninfer-nvfp4-mtp3.example.sh`](configs/ninfer-nvfp4-mtp3.example.sh)

### 94K Codex 호환성 문제

약 94K 프롬프트로 Codex CLI 작업을 처음 돌렸을 때는 실패했습니다. Responses 호환 레이어가 NInfer 경로에서 지원하지 않는 `internal_chat_message_metadata_passthrough`를 그대로 전달한 것이 원인이었습니다.

NInfer 전용 어댑터에서 이 메타데이터만 제거하고 tool argument, output, call ID, message content는 그대로 유지하도록 수정했습니다.

같은 제한된 read → edit → test 작업을 다시 돌리자 **33.409초**에 끝났고 독립 fixture 검사 **3/3**을 통과했습니다.

세 번의 generation decode는 각각:

- 183.2 tok/s
- 174.5 tok/s
- 140.5 tok/s

였습니다.

다만 각 generation의 출력 길이가 짧았기 때문에 이 값은 평균 에이전트 TPS로 쓰지 않고, 94K 근처에서 tool path가 정상 동작했다는 근거로만 남깁니다.

상세: [NInfer 검증 기록](benchmarks/ninfer-qualification-2026-09-09.ko.md)

### 장기 에이전트 작업

NInfer는 이전 로컬 사용에서도 긴 코딩 에이전트 작업을 정상 완료한 적이 있습니다. 다만 그때는 현재와 같은 수준으로 telemetry를 보존하지 않았기 때문에, 과거 실행에 수치를 소급해서 붙이지 않았습니다.

2026-09-16 계측 실행은 별도로 보존했습니다.

[NInfer 장기 에이전트 계측](benchmarks/ninfer-long-agent-live-2026-09-16.md)

공개된 스냅샷 시점에는 작업이 아직 진행 중이었기 때문에 최종 task acceptance는 완료된 것처럼 적지 않았습니다.

## llama.cpp Q5_K_M + MTP3

현재는 보수적인 기본값으로 남겨두고 있습니다. 성능이 항상 더 좋다는 뜻이 아니라, 완료된 장기 작업과 최종 검증 기록이 가장 잘 남아 있기 때문입니다.

### 사용한 구성

- 모델: [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF)
- 테스트 리비전: [`f0eec4a4…c034`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/tree/f0eec4a4bb4975114a030d048952d83c0a53c034)
- 파일: `Qwen3.8-27B-Q5_K_M.gguf`
- SHA-256: `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8`
- llama.cpp build 10435
- 커밋: [`9e40df63…7e99`](https://github.com/ggml-org/llama.cpp/commit/9e40df63ba151d771d8b247ac4011cf203337e99)
- context 131,072
- K/V cache Q8_0 / Q8_0
- Flash Attention 사용
- 66/66 레이어 GPU 적재
- CPU fallback 0
- `parallel=1`
- `batch=2048`
- `ubatch=512`
- MTP3: `--spec-type draft-mtp --spec-draft-n-max 3`

보존된 검증 실행에서 peak VRAM은 약 **28.63 GB**였고 약 **3.98 GiB**가 남았습니다.

설정 예시: [`configs/llamacpp-q5-mtp3-128k.example.ps1`](configs/llamacpp-q5-mtp3-128k.example.ps1)

### 완료된 장기 작업

2026-08-19 실행에서는 다음을 관측했습니다.

- 평균 decode 약 109.51 tok/s
- 최대 확인 context 106,829토큰
- MTP 수락률 89.61%
- prefix cache 16.675M tokens
- cache hit rate 96.8%

테스트 하니스 정리 문제를 수정한 뒤 최종 검증은 다음과 같이 끝났습니다.

- `typecheck PASS`
- `lint PASS`
- `build PASS`
- `vitest 12/12 PASS`

다만 NInfer와 비교 가능한 end-to-end wall time은 수집하지 않았습니다. 따라서 이 실행만으로 두 런타임의 실제 작업 속도를 직접 비교하지 않습니다.

상세: [Q5 장기 에이전트 검증](benchmarks/long-agent-qualification-2026-08-19.md)

## SGLang NVFP4

단일 에이전트 최고 속도용이라기보다 서빙과 동시 요청 쪽 기준 구성으로 남겨둔 런타임입니다.

### 사용한 구성

- 모델: [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4)
- 테스트 리비전: [`52d1adc5…b854`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4/tree/52d1adc5f38aa5ebf099c29ed7025ba34cfbb854)
- SGLang 패키지: `0.0.0.dev0+qwen38.27b.g561c8f3`
- 이미지 빌드 커밋: [`c4271c3f…51c5`](https://github.com/sgl-project/sglang/commit/c4271c3fe1262fc2adbd162c33b25de5255251c5)
- 컨테이너 digest: `sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124`
- context 131,072
- KV FP8 E4M3
- 사용 가능 KV pool 약 148,997토큰
- FlashInfer
- MTP 끔
- `max-running-requests=1`
- `max-mamba-cache-size=5`
- CPU layer offload 0

steady decode는 약 **69.3 tok/s**, 80K+ context에서는 약 **60.8 tok/s**였습니다.

설정 예시: [`configs/sglang-nvfp4-128k.example.sh`](configs/sglang-nvfp4-128k.example.sh)

## 벤치마크 요약

아래 값은 저장소에 공개한 로컬 depth 측정값입니다. context가 길어질 때 decode가 어떻게 변하는지 보는 데는 유용하지만, **같은 날 같은 조건으로 수행한 정식 A/B는 아닙니다.**

| 런타임 | 짧은 입력 | ~32K 표기 | ~80K 표기 | ~114K 표기 |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | ~69.3 | — | ~60.8 | — |
| Q5_K_M + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |
| NInfer NVFP4 + MTP3 | **222.0** | **190.6** | **176.9** | **169.8** |

NInfer에서 각 표기에 대응하는 실제 프롬프트 길이는 **38,717 / 83,917 / 113,956토큰**입니다. 짧은 입력 역시 과거 Q5 측정과 길이가 같지 않습니다.

CSV: [`benchmarks/runtime-comparison.csv`](benchmarks/runtime-comparison.csv)

측정 방법: [`docs/methodology.md`](docs/methodology.md)

## 라우팅 방식

공개된 라우터 파일은 일부러 작은 데이터 명세로만 두었습니다.

[`configs/local-model-router.example.json`](configs/local-model-router.example.json)

동작 흐름은 단순합니다.

1. 작업에 맞는 런타임을 선택합니다.
2. 라우터가 소유한 기존 런타임만 종료합니다.
3. 포트와 VRAM이 실제로 풀렸는지 확인합니다.
4. GPU 스케줄러를 통해 백엔드 하나만 시작합니다.
5. `/v1/models`에서 예상한 모델 ID가 나오는지 확인합니다.
6. 포트나 모델이 다르면 추측해서 진행하지 않고 중단합니다.
7. 선택한 런타임에 맞는 하니스 설정으로 작업을 실행합니다.
8. 런타임 성능과 실제 변경 결과는 별도로 검증합니다.

상세: [agent routing](docs/agent-routing.md)

## 재현 방법

1. 모델은 각 업스트림 저장소에서 직접 받습니다.
2. README에 적힌 리비전과 해시를 확인합니다.
3. NInfer는 WSL2/Linux에서 고정 리비전으로 빌드하고, llama.cpp/SGLang은 해당 버전의 런타임을 준비합니다.
4. `configs/` 아래 예시 경로를 자신의 환경에 맞게 바꿉니다.
5. 별도 인증이나 네트워크 제어를 넣지 않았다면 API는 loopback에만 바인딩합니다.
6. 생성 백엔드는 하나만 시작합니다.
7. [`scripts/healthcheck.example.ps1`](scripts/healthcheck.example.ps1)로 `/v1/models`를 확인합니다.
8. 속도보다 먼저 correctness를 확인합니다.
9. 짧은 코딩 테스트와 장기 에이전트 테스트는 분리해서 봅니다.

전체 절차: [docs/reproducibility.md](docs/reproducibility.md)

## 이 저장소가 증명하지 않는 것

- RTX 5090 한 대에서 얻은 결과이며 여러 장비를 대상으로 한 하드웨어 연구가 아닙니다.
- Q5와 NInfer 장기 작업은 동일한 workload의 정식 A/B가 아닙니다.
- 각 런타임의 짧은 입력과 depth 측정 프롬프트가 완전히 동일하지 않습니다.
- Q5 재검증에서는 NInfer와 비교 가능한 end-to-end wall time을 수집하지 않았습니다.
- 240K는 NInfer 런타임/KV 설정 용량이며, 240K 에이전트 품질을 검증했다는 의미가 아닙니다.
- 과거 NInfer 장기 성공 실행은 현재와 동일한 telemetry 형태로 보존되지 않았습니다.
- 드라이버, 커널, 런타임 커밋, 모델 리비전, 하니스, tool-call 패턴, MTP 수락률에 따라 결과는 달라질 수 있습니다.
- 비전 경로는 테스트하지 않았습니다.

더 자세한 한계: [docs/limitations.md](docs/limitations.md)

## 업스트림 프로젝트

이 저장소는 아래 모델 가중치를 재배포하지 않습니다.

- [`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B)
- [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer)
- [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4)
- [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF)
- [`Neroued/ninfer`](https://github.com/Neroued/ninfer)
- [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp)
- [`sgl-project/sglang`](https://github.com/sgl-project/sglang)
- [`QwenLM/qwen-code`](https://github.com/QwenLM/qwen-code)

실제로 내려받는 리비전의 model card와 라이선스를 직접 확인하는 것을 권장합니다. 이 저장소에서 확인한 라이선스는 [docs/upstream-licenses.md](docs/upstream-licenses.md)에 정리했습니다.

## 라이선스

이 저장소에서 직접 작성한 설정, 문서, 소규모 검증 스크립트와 다이어그램은 MIT 라이선스입니다. 업스트림 모델과 런타임은 각각의 라이선스를 따릅니다.

Qwen, NInfer, RadixArk, bartowski, llama.cpp, SGLang, Qwen Code 프로젝트의 유지보수자와 기여자에게 감사합니다.
