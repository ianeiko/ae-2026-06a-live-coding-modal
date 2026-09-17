"""Small-model LLM demo: same shape as the DeepSeek version, but it actually
fits on one GPU and cold-starts in ~1-2 min. Start here.

    uv run modal run llm_demo.py
"""

import modal

MODEL = "Qwen/Qwen2.5-1.5B-Instruct"  # ~3GB, ungated, no HF token needed

image = (
    modal.Image.debian_slim(python_version="3.12")
    .pip_install("vllm==0.6.6", "huggingface_hub[hf_transfer]==0.27.0")
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1", "HF_HOME": "/cache"})
)

# Weights live here so the download happens once, not once per container.
cache = modal.Volume.from_name("hf-cache", create_if_missing=True)

app = modal.App("llm-demo", image=image)


@app.cls(gpu="L4", volumes={"/cache": cache}, scaledown_window=300)
class Model:
    @modal.enter()
    def load(self):
        from vllm import LLM

        self.llm = LLM(model=MODEL, max_model_len=4096)

    @modal.method()
    def generate(self, prompts: list[str]) -> list[str]:
        from vllm import SamplingParams

        outs = self.llm.chat(
            [[{"role": "user", "content": p}] for p in prompts],
            SamplingParams(temperature=0.7, max_tokens=256),
        )
        return [o.outputs[0].text for o in outs]


@app.local_entrypoint()
def main():
    for text in Model().generate.remote(
        ["Explain what Modal does in two sentences.", "Write a haiku about cold starts."]
    ):
        print(text, "\n---")
