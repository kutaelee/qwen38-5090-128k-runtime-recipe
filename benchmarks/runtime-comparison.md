# Runtime comparison

## Decode throughput

| Runtime | Short | 32K | 80K | 114K |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | ~69.3 | not measured | ~60.8 | not measured |
| Q5_K_M llama.cpp MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |

The SGLang 80K+ value is the 60.77 tok/s median from 43 log samples in the counted long run, rounded to 60.8. Its steady decode median was 69.325 tok/s, rounded to 69.3.

## Correctness and capacity

| Gate | SGLang NVFP4 | Q5_K_M MTP3 |
| --- | --- | --- |
| Server context | 131,072 | 131,072 |
| Available KV capacity | approximately 148,997 tokens | context allocation and 113.9K workload passed |
| CPU layer offload | 0 | 0; all 66/66 layers on GPU |
| Basic | 6/6 | 6/6 |
| JSON schema | 20/20 | 20/20 |
| Tool calls | 40/40 | 40/40 |
| 32K NIAH | 5/5 | 5/5 |
| 80K NIAH | 5/5 | 5/5 |
| 113K+ NIAH | 5/5 | 5/5 |
| CUDA/OOM/output corruption | 0 | 0 |

The table reports the shared qualification suite. Additional SGLang long-context checks reached approximately 124K; those values are documented as capacity/correctness evidence, not added to the throughput chart.

## Agent trajectories

### SGLang NVFP4

- One counted medium web-project run
- Wall time: 526.388 seconds
- Tool calls: 86
- Typecheck, lint, tests 8/8, build, and `git diff --check`: pass
- Major desktop/mobile browser flows: pass
- Final gate: fail, due to one unauthorized generated shadcn file modification and missing mobile Sheet focus restoration

### Q5_K_M MTP3

- Bounded qualification: 10/10 TSX fixtures and multi-file build/test 2/2
- One counted autonomous project run: at least 541 seconds, zero semantic edits
- One 32,768-token completion was consumed by an invalid oversized regex, followed by recovery/context reconstruction
- Final promotion: rejected for long autonomous work; runtime correctness remains passed

## Interpretation

The measured Q5 backend is much faster at token generation. It is also a good bounded worker in this suite. The single autonomous comparison demonstrates that trajectory quality can dominate decode rate. It does not prove that all Q5 agents or all llama.cpp configurations behave this way.
