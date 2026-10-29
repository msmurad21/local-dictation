# Local cleanup latency experiments

Run the actual cleanup pipeline on synthetic text (macOS 26+, Apple Intelligence enabled):

```sh
python3 scripts/benchmarks/apple.py
python3 scripts/benchmarks/apple.py --cases scripts/benchmarks/heldout-cases.json
```

The script supplies 500 ms of prewarming before each measured call, representing work done while recording. The baseline had no explicit prewarm. These timings exclude audio decoding, focus lookup and paste. Two repetitions on one machine are exploratory measurements, not a performance guarantee. Some formatting examples also appear in the prompt; the held-out file provides independent cases.

For optional isolated MLX comparison, install `mlx-lm` in a separate virtual environment and run:

```sh
python scripts/benchmarks/qwen.py /path/to/local/MLX-model
```

This runs individual formatting/correction/vocabulary requests, not the entire app pipeline. Models: `Qwen/Qwen3-0.6B-MLX-4bit` and `Qwen/Qwen3-1.7B-MLX-4bit`. Thinking is disabled, including for older tokenizer templates that ignore `enable_thinking=False`. The app does not depend on Python, MLX or these downloads.

## Findings, 2026-10-29

Hardware: Apple M3 Pro, 18 GiB RAM, macOS 26.6.2. MLX 0.32.4 and mlx-lm 0.32.2. Raw synthetic outputs and durations are in `results/`.

Whisper Base, already loaded, decoded the synthetic paragraph in 0.38–0.51 seconds across three runs. Cold loading took about 8.2 seconds; the app already loads and retains the speech engine at startup. One decode added a trailing word, so these measurements do not establish recognition accuracy. Streaming audio was not introduced in this change.

Median cleanup time across two runs (seconds; synthetic examples):

| Example | v0.12.1 | v0.13.0 |
| --- | ---: | ---: |
| Prose | 1.260 | 0.744 |
| Explicit list | 0.607 | 0.610 |
| Date correction | 1.101 | 1.091 |
| SwiftUI jargon | 4.633 | 1.025 |
| Actually-no restatement | 0.558 | 0.395 |

The previous cleanup pipeline generated unwanted Swift code for a dictated coding request, rejected it, and retried: roughly 4.6 seconds. Constrained JSON layout avoids generating an answer to that request. Every accepted layout still passes the existing word-order, number and protected-content checks. Formatting failures preserve the transcript; they do not trigger unbounded retries.

Qwen 0.6B: warm requests roughly 0.09–0.19 seconds; peak MLX allocation about 676 MB. Its correction chose Tuesday as both the target and replacement instead of changing Monday, and its bullet output kept all items on one line. It is not a suitable default from these results.

Qwen 1.7B: warm requests roughly 0.32–0.77 seconds; peak MLX allocation about 1.32 GB. It found the date correction but also proposed an unrelated extra edit; its vocabulary response added an unallowed UIView replacement. Existing validators would reject those extra edits. List structure was still inadequate. Cold first-generation costs were higher for both models. MLX allocation excludes Python and other process memory.

The release retains Apple's local model. These small tests do not establish that either Qwen variant would improve end-to-end latency or quality. Combined jargon/correction examples and some inferred procedures remain known quality gaps, including in the previous pipeline; no claim of universal cue recognition is made.

The dashboard now records recording-stop to **paste event sent**, with separate decoding, cleanup and paste-wait durations. This does not confirm that the destination rendered the text. It includes audio finalization and contextual reprocessing, but excludes the 900 ms clipboard-restoration wait after the paste event. No timing or transcript data is uploaded.
