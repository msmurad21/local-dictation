"""Optional isolated benchmark. Requires mlx-lm; never used by the app."""
import argparse, json, time
from pathlib import Path
from mlx_lm import load, generate
from mlx_lm.sample_utils import make_sampler
import mlx.core as mx
parser = argparse.ArgumentParser()
parser.add_argument("model", help="Local MLX model directory or Hugging Face model ID")
args = parser.parse_args()
start = time.perf_counter()
model, tokenizer = load(args.model)
print(json.dumps({"load_seconds": time.perf_counter()-start}), flush=True)
requests = [json.loads(line) for line in Path(__file__).with_name("model-requests.jsonl").read_text().splitlines()]
for round in range(2):
    for case in requests:
        prompt = tokenizer.apply_chat_template([{"role":"system", "content":case["system"]}, {"role":"user", "content":case["prompt"]}], tokenize=False, add_generation_prompt=True, enable_thinking=False)
        # Older Qwen exports omit enable_thinking support in their template.
        if not prompt.endswith("<think>\n\n</think>\n\n"):
            prompt += "<think>\n\n</think>\n\n"
        start = time.perf_counter()
        result = generate(model, tokenizer, prompt=prompt, max_tokens=1000, sampler=make_sampler(temp=0), verbose=False)
        mx.synchronize()
        print(json.dumps({"id":case["id"], "round":round, "seconds":time.perf_counter()-start, "response":result, "peak_memory_mb":mx.get_peak_memory()/1e6}), flush=True)
