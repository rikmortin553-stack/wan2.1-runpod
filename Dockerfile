# 1. БАЗА: Строго CUDA 12.8 Devel (нужен Devel для компиляции SageAttention)
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
# Указываем архитектуру GPU RTX 5090 (sm_120) для компиляторов
ENV TORCH_CUDA_ARCH_LIST="12.0"

WORKDIR /

# 2. СИСТЕМНЫЕ ЗАВИСИМОСТИ
# ninja-build обязателен для сборки ядер
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev \
    git wget curl aria2 build-essential ninja-build \
    libgl1-mesa-glx libglib2.0-0 rsync \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. PYTHON 3.11
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip install --no-cache-dir --upgrade pip wheel setuptools

# 4. PYTORCH NIGHTLY (Единственный рабочий вариант для CUDA 12.8)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

# 5. БАЗОВЫЕ БИБЛИОТЕКИ (ONNX, OpenCV и прочее)
RUN pip install --no-cache-dir \
    numpy pillow scipy tqdm psutil requests pyyaml huggingface_hub \
    safetensors transformers>=4.38.0 accelerate einops sentencepiece \
    opencv-python kornia spandrel soundfile jupyterlab \
    onnxruntime-gpu GitPython rembg imageio-ffmpeg matplotlib pandas

# 6. КЛОНИРУЕМ COMFYUI В ОБРАЗ (В /comfy-build)
# Чтобы он был готов заранее
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-build
WORKDIR /comfy-build
RUN pip install --no-cache-dir -r requirements.txt

# Копируем скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000 8888
CMD ["/start.sh"]
