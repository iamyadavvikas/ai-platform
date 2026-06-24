import asyncio
import random
import statistics
import time

import httpx

PROXY_URL = "http://proxy:8000/v1/chat/completions"
BATCH_SIZE = 20
STATS_INTERVAL = 10

PROMPTS = [
    "Explain quantum computing in simple terms.",
    "Write a poem about artificial intelligence.",
    "What is the difference between supervised and unsupervised learning?",
    "Describe the transformer architecture in NLP.",
    "How does gradient descent work?",
    "Explain the concept of attention mechanisms.",
    "What are the benefits of microservices architecture?",
    "Describe how Kubernetes manages container orchestration.",
    "What is a vector database and how does it work?",
    "Explain the CAP theorem in distributed systems.",
    "Write a haiku about machine learning.",
    "What is the difference between REST and gRPC?",
    "Explain how Docker containers isolate processes.",
    "Describe the concept of infrastructure as code.",
    "What is MLOps and why is it important?",
    "Explain the difference between TCP and UDP.",
    "Describe how SSL/TLS encryption works.",
    "What is a sidecar pattern in service mesh?",
    "Explain the concept of eventual consistency.",
    "Describe how Prometheus monitoring works.",
]

RequestResult = tuple[int, float, str | None]


async def send_request(client: httpx.AsyncClient, prompt: str) -> RequestResult:
    payload = {
        "model": "phi3:mini",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 256,
        "temperature": 0.7,
    }
    start = time.monotonic()
    try:
        resp = await client.post(PROXY_URL, json=payload, timeout=30.0)
        status = resp.status_code
        elapsed = time.monotonic() - start
        return (status, elapsed, None)
    except Exception as e:
        elapsed = time.monotonic() - start
        return (0, elapsed, str(e))


def rate_for_phase(elapsed: float) -> float:
    if elapsed < 60:
        return 100.0 / 60.0
    elif elapsed < 120:
        phase_elapsed = elapsed - 60
        return (100.0 + (phase_elapsed / 60.0) * 4900.0) / 60.0
    elif elapsed < 180:
        return 5000.0 / 60.0
    elif elapsed < 240:
        phase_elapsed = elapsed - 180
        return (5000.0 * (1.0 - phase_elapsed / 60.0)) / 60.0
    else:
        return 0.0


async def main():
    print("Load generator starting...")
    start_time = time.monotonic()
    total_count = 0
    error_count = 0
    latencies = []
    last_stats_time = start_time

    async with httpx.AsyncClient(timeout=30.0) as client:
        while True:
            elapsed = time.monotonic() - start_time
            target_rps = rate_for_phase(elapsed)

            if target_rps <= 0:
                if total_count > 0:
                    print(f"\nPhase complete. Total requests: {total_count}, errors: {error_count}")
                await asyncio.sleep(1)
                continue

            batch_start = time.monotonic()
            tasks = []
            n = min(BATCH_SIZE, max(1, int(target_rps)))
            selected_prompts = random.choices(PROMPTS, k=n)

            for prompt in selected_prompts:
                tasks.append(send_request(client, prompt))

            results = await asyncio.gather(*tasks)
            now = time.monotonic()

            for status, lat, err in results:
                total_count += 1
                if err or status >= 400:
                    error_count += 1
                else:
                    latencies.append(lat)

            if now - last_stats_time >= STATS_INTERVAL:
                avg_lat = statistics.mean(latencies) if latencies else 0.0
                p99_lat = sorted(latencies)[int(len(latencies) * 0.99) - 1] if len(latencies) >= 100 else (sorted(latencies)[-1] if latencies else 0.0)
                actual_rps = total_count / (now - start_time) if (now - start_time) > 0 else 0
                print(
                    f"[{int(now - start_time):4d}s] "
                    f"req/s: {actual_rps:6.1f} "
                    f"total: {total_count:5d} "
                    f"errors: {error_count:4d} "
                    f"avg_lat: {avg_lat*1000:6.0f}ms "
                    f"p99_lat: {p99_lat*1000:6.0f}ms "
                    f"target_rps: {target_rps:5.1f}"
                )
                latencies.clear()
                last_stats_time = now

            batch_duration = time.monotonic() - batch_start
            sleep = max(0, (n / target_rps if target_rps > 0 else 1.0) - batch_duration)
            await asyncio.sleep(sleep)


if __name__ == "__main__":
    asyncio.run(main())
