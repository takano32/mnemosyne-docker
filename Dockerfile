FROM python:3.14-slim

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --upgrade "mnemosyne-memory[mcp]"

ENV MNEMOSYNE_DATA_DIR=/data

RUN mkdir -p /data

EXPOSE 8765

CMD ["mnemosyne", "mcp", "--transport", "sse", "--host", "0.0.0.0", "--port", "8765"]
