# ------------------------------------------------------------------------------
# Dockerfile: ComfyUI Wan 2.1 Optimized for RTX 5090 (Blackwell/sm_120)
# Base: NVIDIA CUDA 12.8 Devel on Ubuntu 22.04
# Источник решения: Твой документ №2
# ------------------------------------------------------------------------------

# Использование devel-образа ОБЯЗАТЕЛЬНО для компиляции ядер под sm_120
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

LABEL maintainer="ComfyUI-Blackwell-Ops"
LABEL description="Среда для запуска Wan 2.1 на RTX 5090 с CUDA 12.8 и PyTorch Nightly"

# Отключение диалогов и буферизации
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ------------------------------------------------------------------------------
# 1. Системные зависимости (Добавил ninja-build и git для компиляции)
# ------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    git \
    wget \
    curl \
    aria2 \
    build-essential \
    ninja-build \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Делаем python3.11 основным
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# ------------------------------------------------------------------------------
# 2. Виртуальное окружение и PIP
# ------------------------------------------------------------------------------
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip install --no-cache-dir --upgrade pip wheel setuptools

# ------------------------------------------------------------------------------
# 3. Установка PyTorch Nightly (CUDA 12.8) - КРИТИЧЕСКИЙ ШАГ
# ------------------------------------------------------------------------------
# Согласно документу, ставим версию с поддержкой sm_120
RUN pip install --no-cache-dir --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu128

# ------------------------------------------------------------------------------
# 4. Базовые зависимости ComfyUI (Чтобы ускорить запуск)
# ------------------------------------------------------------------------------
RUN pip install --no-cache-dir \
    numpy pillow scipy tqdm psutil requests pyyaml huggingface_hub \
    safetensors transformers>=4.38.0 accelerate einops sentencepiece \
    opencv-python kornia spandrel soundfile jupyterlab

# ------------------------------------------------------------------------------
# 5. КОМПИЛЯЦИЯ SAGEATTENTION (ГЛАВНОЕ ИСПРАВЛЕНИЕ)
# ------------------------------------------------------------------------------
# Указываем компилятору, что мы собираем под RTX 5090 (Arch 12.0)
ENV TORCH_CUDA_ARCH_LIST="12.0"
ENV MAX_JOBS=8

WORKDIR /tmp
# Клонируем и собираем из исходников. Флаг --no-build-isolation важен!
RUN echo "Compiling SageAttention for Blackwell..." && \
    git clone https://github.com/thu-ml/SageAttention.git && \
    cd SageAttention && \
    pip install . --no-build-isolation

# Чистим мусор
WORKDIR /
RUN rm -rf /tmp/SageAttention

# ------------------------------------------------------------------------------
# 6. Финализация
# ------------------------------------------------------------------------------
WORKDIR /workspace

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Порт 3000 - стандарт для прокси RunPod (согласно отчету)
EXPOSE 3000 8888

CMD ["/start.sh"]
