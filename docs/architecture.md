> Current decision (2026-09-09): Q5/MTP3 remains the default; NInfer is an explicit qualification candidate. See [measured results](../benchmarks/ninfer-qualification-2026-09-09.md). The legacy route key `single-agent-fallback` now selects the default Q5 profile.

# Architecture

## Components

```text
task packet
    |
    v
purpose classifier
    |-- explicit qualification candidate    --> NInfer NVFP4 MTP3 :8083
    |-- default single-agent                --> llama.cpp Q5_K_M MTP3 :8082
    `-- multi-tenant / high-concurrency     --> SGLang NVFP4 :30000
                                      
selected loopback endpoint --> Qwen Code --> workspace tools
                                      |
                                      v
                         independent acceptance gates
```

The router is a lifecycle controller, not a load balancer. It never assumes enough VRAM for both 27B backends. The sequence is:

1. classify the task;
2. verify who owns the currently active server;
3. stop only an owned server and confirm VRAM/port release;
4. start one selected backend through a GPU scheduler;
5. verify the exact model ID from `/v1/models`;
6. run the agent with task-local settings (`skipLoopDetection: true`, external semantic guard);
7. validate the output independently (`typecheck`, `lint`, `test`, `build`, `git diff --check`);
8. stop and clean up unless residency was explicitly requested.

## Trust boundaries

- Both APIs are loopback-only.
- Model weights remain in runtime-owned caches outside the source repository.
- The agent receives an exact workspace and change scope.
- External research, credentials, deployments, and remote writes stay outside the local worker.
- The primary orchestrator treats worker completion as an attempt, not proof.

## Runtime isolation

NInfer is built and run in WSL2/Linux from `~/src/ninfer` against an ext4-native `.ninfer` artifact. SGLang runs in WSL2/Docker with an ext4-native Hugging Face cache. llama.cpp runs as a Windows CUDA binary against a Windows-native GGUF. Crossing the WSL `/mnt/*` boundary for multi-gigabyte weights is deliberately avoided.
