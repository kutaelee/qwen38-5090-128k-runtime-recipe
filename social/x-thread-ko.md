# X thread draft — Korean

아래 초안은 공개 전 최종 검토본이다. 각 post는 280자 이하로 검증한다.

## 1

RTX 5090 한 장에서 Qwen3.8-27B를 128K로 운용한 recipe를 정리 중입니다. 하나의 “최고 runtime”을 찾기보다 long-horizon 작업과 bounded coding을 서로 다른 backend로 라우팅했습니다.

## 2

bounded worker는 Q5_K_M + llama.cpp + Q8 K/V + MTP3. short 151.7 t/s, 80K 98.6 t/s, 114K 94.7 t/s, peak에서도 약 2.1 GiB VRAM free. basic/JSON/tool call/long-context correctness는 전부 통과했습니다.

## 3

Qwen Code bounded qualification도 10/10 TSX fixture PASS, 작은 multi-file 작업은 build/test 2/2 PASS. 빠르고 범위가 명확한 patch나 tool-use에는 이쪽이 잘 맞았습니다.

## 4

그런데 동일한 long-agent task에서는 결과가 반대였습니다. 약 69 t/s SGLang baseline은 526.4초에 구현을 끝냈지만, 151 t/s Q5/MTP3는 541초가 지나도 semantic edit가 0건이었습니다.

## 5

Q5 run은 한 번의 32768-token completion을 비정상적으로 큰 regex 생성에 썼고 invalid-regex → recovery/context reconstruction 경로로 빠졌습니다. runtime corruption은 아니었고 agent trajectory 문제였습니다. N=1 결과라 일반화하진 않습니다.

## 6

long route는 RadixArk Qwen3.8-27B NVFP4 + SGLang, FP8 E4M3 KV, FlashInfer, MTP OFF. steady decode 약 69.3 t/s, 80K+ 약 60.8 t/s, KV pool 약 148,997 tokens입니다.

## 7

SGLang medium web run은 약 8m46s / 86 tool calls. typecheck, lint, tests 8/8, build와 주요 desktop/mobile flow는 통과했습니다. 다만 unauthorized shadcn file 수정 1건과 mobile Sheet focus restore 실패는 그대로 공개합니다.

## 8

현재 운영 분기는 단순합니다.

planning / integration / long autonomous → SGLang NVFP4

quick code / bounded implementation / tool use → Q5_K_M + llama.cpp + MTP3

둘을 동시에 GPU에 상주시키지는 않습니다.

## 9

raw TPS != agent throughput. decode가 빠르면 유리하지만, tool call과 compaction, 잘못된 trajectory 한 번이 wall-clock을 전부 뒤집을 수 있었습니다. config, benchmark methodology, 실패 결과까지 공개용 repo에 넣었습니다.

## 10

GitHub: https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe

Hugging Face: https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe

weights는 재배포하지 않고 Qwen/RadixArk/bartowski 원본 repo만 링크합니다. 재현 결과나 다른 5090 세팅은 GitHub Issues에서 공유해주세요.
