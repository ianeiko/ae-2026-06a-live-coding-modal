"""DeepSeek-V4-Flash on Modal. Same structure as llm_demo.py, but 284B params
(13B activated, MoE) and ~160GB of FP4/FP8 weights, so it needs a multi-GPU box.

Read the cost note at the bottom before running this.

    uv run modal run deepseek_v4_flash.py --prompt "..."
"""

import modal

MODEL = "deepseek-ai/DeepSeek-V4-Flash"
N_GPU = 2  # 2x H200 = 282GB VRAM; ~160GB weights + KV cache

image = (
    modal.Image.debian_slim(python_version="3.12")
    .pip_install("vllm==0.6.6", "huggingface_hub[hf_transfer]==0.27.0")
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1", "HF_HOME": "/cache", "VLLM_USE_V1": "1"})
)

cache = modal.Volume.from_name("hf-cache", create_if_missing=True)

app = modal.App("deepseek-v4-flash", image=image)


@app.function(
    volumes={"/cache": cache},
    timeout=60 * 60,  # 160GB pull takes a while on a cold cache
)
def download():
    """Run once: uv run modal run deepseek_v4_flash.py::download"""
    from huggingface_hub import snapshot_download

    snapshot_download(MODEL)
    cache.commit()


@app.cls(
    gpu=f"H200:{N_GPU}",
    volumes={"/cache": cache},
    timeout=60 * 60,
    scaledown_window=600,  # keep it warm; reloading 160GB is the expensive part
)
class Model:
    @modal.enter()
    def load(self):
        from vllm import LLM

        self.llm = LLM(
            model=MODEL,
            tensor_parallel_size=N_GPU,
            # The model supports 1M context. Asking for it allocates a huge KV
            # cache; start small and raise it only when you need long context.
            max_model_len=8192,
            trust_remote_code=True,
        )

    @modal.method()
    def generate(self, prompt: str) -> str:
        from vllm import SamplingParams

        out = self.llm.chat(
            [{"role": "user", "content": prompt}],
            SamplingParams(temperature=0.7, max_tokens=512),
        )
        return out[0].outputs[0].text


@app.local_entrypoint()
def main(prompt: str = "Explain mixture-of-experts routing in three sentences."):
    print(Model().generate.remote(prompt))
