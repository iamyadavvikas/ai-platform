import asyncio
import os
import random
import time
import uuid

import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

app = FastAPI(title="AI Platform Proxy")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")
MODEL_NAME = os.getenv("MODEL_NAME", "phi3:mini")
MOCK_MODE = os.getenv("MOCK_MODE", "true").lower() in ("true", "1", "yes")
SIMULATE_LATENCY_MS = int(os.getenv("SIMULATE_LATENCY_MS", "500"))
SIMULATE_TOKENS_PER_SEC = int(os.getenv("SIMULATE_TOKENS_PER_SEC", "45"))

llm_requests_total = Counter(
    "llm_requests_total",
    "Total LLM requests",
    ["model", "status"],
)
llm_request_duration_seconds = Histogram(
    "llm_request_duration_seconds",
    "LLM request duration in seconds",
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0),
)
llm_tokens_per_second = Histogram(
    "llm_tokens_per_second",
    "Tokens generated per second",
    buckets=(5, 10, 20, 50, 100, 200),
)
llm_active_requests = Gauge(
    "llm_active_requests",
    "Currently active LLM requests",
)
llm_prompt_tokens = Histogram(
    "llm_prompt_tokens",
    "Prompt token count",
    buckets=(10, 50, 100, 200, 500, 1000, 2000),
)
llm_completion_tokens = Histogram(
    "llm_completion_tokens",
    "Completion token count",
    buckets=(10, 50, 100, 200, 500, 1000, 2000),
)


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    model: str | None = None
    messages: list[ChatMessage]
    stream: bool = False
    max_tokens: int = 256
    temperature: float = 0.7


MOCK_RESPONSES = [
    "Quantum computing leverages superposition and entanglement to perform computations "
    "that would be infeasible for classical computers. By using qubits instead of bits, "
    "quantum algorithms can explore multiple states simultaneously.",
    "Machine learning is a subset of artificial intelligence that enables systems to learn "
    "and improve from experience without being explicitly programmed. It focuses on "
    "developing algorithms that can access data and use it to learn for themselves.",
    "The transformer architecture revolutionized natural language processing by introducing "
    "self-attention mechanisms. This allows the model to weigh the importance of different "
    "words in a sequence, capturing long-range dependencies effectively.",
    "A microservices architecture structures an application as a collection of loosely coupled "
    "services. Each service is independently deployable, scalable, and maintains its own "
    "database, enabling faster development cycles and better fault isolation.",
    "Kubernetes is an open-source container orchestration platform that automates deployment, "
    "scaling, and management of containerized applications. It groups containers into pods, "
    "which are the smallest deployable units in the platform.",
]


def _estimate_tokens(text: str) -> int:
    return max(1, len(text.split()))


def _generate_mock_completion() -> str:
    base = random.choice(MOCK_RESPONSES)
    extra_sentences = random.randint(0, 4)
    extras = [
        "This approach has significant implications for the field.",
        "Further research is needed to fully understand these effects.",
        "Practical applications continue to emerge as the technology matures.",
        "These findings align with previous work in the domain.",
    ]
    if extra_sentences > 0:
        base += " " + " ".join(random.choices(extras, k=extra_sentences))
    return base


async def _call_ollama(request: ChatCompletionRequest) -> dict:
    prompt = request.messages[-1].content if request.messages else ""
    payload = {
        "model": request.model or MODEL_NAME,
        "prompt": prompt,
        "stream": False,
        "options": {
            "num_predict": request.max_tokens,
            "temperature": request.temperature,
        },
    }
    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(f"{OLLAMA_URL}/api/generate", json=payload)
        resp.raise_for_status()
        data = resp.json()

    completion = data.get("response", "")
    prompt_tokens = data.get("prompt_eval_count", _estimate_tokens(prompt))
    completion_tokens = data.get("eval_count", _estimate_tokens(completion))

    return {
        "id": f"chatcmpl-{uuid.uuid4().hex}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": request.model or MODEL_NAME,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": completion,
                },
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": prompt_tokens + completion_tokens,
        },
    }


async def _generate_mock_response(request: ChatCompletionRequest) -> dict:
    prompt = request.messages[-1].content if request.messages else ""
    prompt_tokens = _estimate_tokens(prompt)

    latency = random.gauss(SIMULATE_LATENCY_MS, SIMULATE_LATENCY_MS * 0.1)
    latency = max(50.0, latency)
    await asyncio.sleep(latency / 1000.0)

    completion = _generate_mock_completion()
    completion_tokens = _estimate_tokens(completion)

    effective_tps = completion_tokens / (latency / 1000.0) if latency > 0 else SIMULATE_TOKENS_PER_SEC

    return {
        "id": f"chatcmpl-{uuid.uuid4().hex}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": request.model or MODEL_NAME,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": completion,
                },
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": prompt_tokens + completion_tokens,
        },
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "mock_mode": MOCK_MODE}


@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "created": int(time.time()),
                "owned_by": "ai-platform",
            }
        ],
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    model = request.model or MODEL_NAME
    llm_active_requests.inc()
    start = time.monotonic()

    try:
        if MOCK_MODE:
            result = await _generate_mock_response(request)
        else:
            result = await _call_ollama(request)

        duration = time.monotonic() - start
        prompt_tokens = result["usage"]["prompt_tokens"]
        completion_tokens = result["usage"]["completion_tokens"]
        tps = completion_tokens / duration if duration > 0 else 0

        llm_requests_total.labels(model=model, status="success").inc()
        llm_request_duration_seconds.observe(duration)
        llm_tokens_per_second.observe(tps)
        llm_prompt_tokens.observe(prompt_tokens)
        llm_completion_tokens.observe(completion_tokens)

        return result
    except Exception as e:
        duration = time.monotonic() - start
        llm_requests_total.labels(model=model, status="error").inc()
        llm_request_duration_seconds.observe(duration)
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "model": model},
        )
    finally:
        llm_active_requests.dec()


@app.get("/metrics")
async def metrics():
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )
