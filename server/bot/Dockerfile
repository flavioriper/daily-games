FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/* && pip install --no-cache-dir uv
WORKDIR /app
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --no-install-project
COPY . .
ENV FASTEMBED_CACHE_PATH=/app/.fastembed
# Both embedders are baked in, so a cold start never downloads a model: the device memory's (English) and the
# shared layer's (multilingual, shared/store.py).
RUN /app/.venv/bin/python -c "from memory.embed import embed; embed(['warm'])" \
 && /app/.venv/bin/python -c "from shared.store import embed_texts; embed_texts(['warm'])"
ENV HOST=0.0.0.0 PORT=8080 STUDIO_LOCAL=/tmp/studio STUDIO_DATA=/data
CMD ["/app/.venv/bin/python", "server.py"]
