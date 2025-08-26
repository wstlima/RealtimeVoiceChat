ARG WHISPER_MODEL=small

# ---------- Stage 1: builder ----------
FROM python:3.10-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies and helpers
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libsndfile1 \
    libportaudio2 \
    ffmpeg \
    portaudio19-dev \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama runtime
RUN curl -fsSL https://ollama.com/install.sh | sh

WORKDIR /app




# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir torch torchaudio torchvision --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir --prefer-binary -r requirements.txt
    # pip install --no-cache-dir --z noexecstack "ctranslate2<4.5.0"

# Copy application code and entrypoint
COPY --chown=1001:1001 code/ ./code/
# COPY --chown=1001:1001 entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

# Create non-root user and set cache locations
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid 1001 --create-home appuser
ENV HOME=/home/appuser
ENV HF_HOME=${HOME}/.cache/huggingface
ENV TORCH_HOME=${HOME}/.cache/torch
ENV PYTHONUNBUFFERED=1
ENV MAX_AUDIO_QUEUE_SIZE=50
ENV LOG_LEVEL=INFO
ENV RUNNING_IN_DOCKER=true
ENV LLM_START_PROVIDER=ollama
ENV LLM_START_MODEL=huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0
ENV WHISPER_MODEL=${WHISPER_MODEL}
USER appuser

# Pre-download models to speed up container startup
RUN echo "Preloading Silero VAD model..." && \
    python - <<'PYTHON'
import torch, os
cache_dir = os.path.expanduser("~/.cache/torch")
os.environ['TORCH_HOME'] = cache_dir
torch.hub.load('snakers4/silero-vad', 'silero_vad', onnx=False, trust_repo=True)
PYTHON

RUN echo "Preloading SentenceFinishedClassification model..." && \
    python - <<'PYTHON'
from transformers import DistilBertTokenizerFast, DistilBertForSequenceClassification
DistilBertTokenizerFast.from_pretrained('KoljaB/SentenceFinishedClassification')
DistilBertForSequenceClassification.from_pretrained('KoljaB/SentenceFinishedClassification')
PYTHON

# Pull Ollama model during build
# RUN ollama pull Phi-3-mini-4k-instruct-Q4_K_M.gguf


# ---------- Stage 2: runtime ----------
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    libportaudio2 \
    ffmpeg \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama runtime
RUN curl -fsSL https://ollama.com/install.sh | sh

# Set working directory for the application
WORKDIR /app/code

# Create non-root user
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid 1001 --create-home appuser

# Copy installed Python packages from the builder stage
RUN mkdir -p /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages    



# Copy application and caches from builder
COPY --from=builder --chown=1001:1001 /app /app
COPY --from=builder --chown=1001:1001 /home/appuser /home/appuser
# COPY --from=builder --chown=1001:1001 /entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

# Environment variables
ENV HOME=/home/appuser
ENV PYTHONUNBUFFERED=1
ENV MAX_AUDIO_QUEUE_SIZE=50
ENV LOG_LEVEL=INFO
ENV RUNNING_IN_DOCKER=true
ENV HF_HOME=${HOME}/.cache/huggingface
ENV TORCH_HOME=${HOME}/.cache/torch
ENV LLM_START_PROVIDER=ollama
ENV LLM_START_MODEL=huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0
ARG WHISPER_MODEL=small
ENV WHISPER_MODEL=${WHISPER_MODEL}

EXPOSE 8000

# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]