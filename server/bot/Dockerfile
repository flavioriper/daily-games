FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/* && pip install --no-cache-dir uv
WORKDIR /app
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --no-install-project
COPY . .
ENV FASTEMBED_CACHE_PATH=/app/.fastembed
RUN /app/.venv/bin/python -c "from memory.embed import embed; embed(['warm'])"
ENV HOST=0.0.0.0 PORT=8080 STUDIO_LOCAL=/tmp/studio STUDIO_DATA=/data
CMD ["/app/.venv/bin/python", "server.py"]
