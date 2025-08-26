ARG WHISPER_MODEL=small

FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
# USER root
# RUN useradd -ms /bin/bash appuser
RUN groupadd --gid 1001 appgroup 
RUN useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash appuser
RUN usermod -aG root appuser
RUN mkdir -p /app/code 

RUN mkdir -p /home/appuser/.local/bin
RUN mkdir -p /home/appuser/.local/lib/python3.10/site-packages
RUN mkdir -p /home/appuser/.cache/huggingface
RUN mkdir -p /home/appuser/.cache/torch
RUN mkdir -p /home/appuser/.cache/torch/hub/checkpoints

# RUN mkdir -p /usr/local/lib/python3.10/site-packages


RUN     chown -R appuser:appgroup /home/appuser && \
    chmod 750 /home/appuser && \
    mkdir -p /home/appuser/.cache/huggingface /home/appuser/.cache/torch && \
    chown -R appuser:appgroup /home/appuser/.cache && \
    chmod -R 750 /home/appuser/.cache && \
    mkdir -p /home/appuser/.cache/torch/hub/checkpoints && \
    chown -R appuser:appgroup /home/appuser/.cache/torch/hub/checkpoints && \
    chmod -R 750 /home/appuser/.cache/torch/hub/checkpoints

# Removed unnecessary chown/chmod on pip binary


RUN mkdir -p /usr/local/lib/python3.10/site-packages && \
    chown -R appuser:appgroup /usr/local/lib/python3.10/site-packages && \
    chmod -R 755 /usr/local/lib/python3.10/site-packages    

# RUN mkdir -p /app/code && \
#     chown -R appuser:appgroup /app/code && \
#     chmod -R 750 /app/code
# COPY --chown=1001:1001 entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh        

ENV PATH=$PATH:/home/appuser/.local/bin
ENV PYTHONUSERBASE=/home/appuser/.local

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
# RUN curl -fsSL https://ollama.com/install.sh | sh

WORKDIR /app













# Copy application code and entrypoint
RUN mkdir -p /app/code && \
chown -R appuser:appgroup /app/code && \
chmod -R 750 /app/code
COPY --chown=1001:1001 code/ ./code/
# COPY --chown=1001:1001 entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh    

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


# Install Python dependencies
# USER appuser

COPY requirements.txt ./
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir torch torchaudio torchvision --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir --prefer-binary -r requirements.txt
# pip install --no-cache-dir --z noexecstack "ctranslate2<4.5.0"
# USER root    
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
# FROM python:3.10-slim

# ENV DEBIAN_FRONTEND=noninteractive

# RUN apt-get update && apt-get install -y --no-install-recommends \
#     build-essential \
#     git \
#     libsndfile1 \
#     libportaudio2 \
#     ffmpeg \
#     portaudio19-dev \
#     curl \
#     gosu \
#     && rm -rf /var/lib/apt/lists/*

# Install Ollama runtime
# RUN curl -fsSL https://ollama.com/install.sh | sh

# Set working directory for the application
WORKDIR /app/code

# Create non-root user
# RUN groupadd --gid 1001 appgroup && \
#     useradd --uid 1001 --gid 1001 --create-home appuser

# Copy installed Python packages from the builder stage
# RUN mkdir -p /usr/local/lib/python3.10/site-packages
# COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages    
# COPY --from=builder /home/appuser/.local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages    



# Copy application and caches from builder
# COPY --from=builder --chown=1001:1001 /app /app
# COPY --from=builder --chown=1001:1001 /entrypoint.sh /entrypoint.sh
# COPY --from=builder --chown=1001:1001 /home/appuser /home/appuser
# RUN chmod +x /entrypoint.sh

# Environment variables
# ENV HOME=/home/appuser
# ENV PYTHONUNBUFFERED=1
# ENV MAX_AUDIO_QUEUE_SIZE=50
# ENV LOG_LEVEL=INFO
# ENV RUNNING_IN_DOCKER=true
# ENV HF_HOME=${HOME}/.cache/huggingface
# ENV TORCH_HOME=${HOME}/.cache/torch
# ENV LLM_START_PROVIDER=ollama
# ENV LLM_START_MODEL=hf.co/bartowski/huihui-ai_Mistral-Small-24B-Instruct-2501-abliterated-GGUF:Q4_K_M
# ARG WHISPER_MODEL
# ENV WHISPER_MODEL=${WHISPER_MODEL}


# USER root

EXPOSE 8000

# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
# CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000", "--reload", "--reload-dir", "/app/code"]
