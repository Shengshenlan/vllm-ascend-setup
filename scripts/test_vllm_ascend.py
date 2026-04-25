#!/usr/bin/env python3
"""Smoke test for vllm-ascend."""

import argparse
import os

from vllm import LLM, SamplingParams


DEFAULT_PROMPTS = [
    "Hello, my name is",
    "The president of the United States is",
    "The capital of France is",
    "The future of AI is",
]


def parse_args():
    parser = argparse.ArgumentParser(description="Run a small vllm-ascend generation test.")
    parser.add_argument(
        "--model",
        default=os.environ.get("VLLM_ASCEND_TEST_MODEL", "Qwen/Qwen3-0.6B"),
        help="Model name or local path. Defaults to VLLM_ASCEND_TEST_MODEL or Qwen/Qwen3-0.6B.",
    )
    parser.add_argument("--temperature", type=float, default=0.8)
    parser.add_argument("--top-p", type=float, default=0.95)
    parser.add_argument("--max-tokens", type=int, default=32)
    parser.add_argument("--trust-remote-code", action="store_true")
    parser.add_argument(
        "--prompt",
        action="append",
        dest="prompts",
        help="Prompt to generate from. Can be passed multiple times.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    prompts = args.prompts or DEFAULT_PROMPTS

    sampling_params = SamplingParams(
        temperature=args.temperature,
        top_p=args.top_p,
        max_tokens=args.max_tokens,
    )
    llm = LLM(model=args.model, trust_remote_code=args.trust_remote_code)

    outputs = llm.generate(prompts, sampling_params)
    for output in outputs:
        generated_text = output.outputs[0].text
        print(f"Prompt: {output.prompt!r}, Generated text: {generated_text!r}")


if __name__ == "__main__":
    main()
