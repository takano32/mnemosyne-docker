FROM python:3.14-slim

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --upgrade "mnemosyne-memory[mcp,embeddings]"

ENV MNEMOSYNE_DATA_DIR=/data \
    MNEMOSYNE_FASTEMBED_CACHE_DIR=/data/cache/fastembed

RUN mkdir -p /data

EXPOSE 8765

CMD ["mnemosyne", "mcp", "--transport", "sse", "--host", "0.0.0.0", "--port", "8765"]
