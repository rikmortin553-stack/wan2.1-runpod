# 1. БАЗА (Строго CUDA 12.8.1, как в логах)
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1 
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

WORKDIR /

# 2. ПОДГОТОВКА (Системные либы)
RUN apt-get update && apt-get install -y \
    build-essential libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
    libnss3-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev \
    libgdbm-dev libc6-dev uuid-dev tk-dev \
    git wget aria2 ffmpeg libgl1-mesa-glx libglib2.0-0 rsync curl \
    && rm -rf /var/lib/apt/lists/*

# 3. PYTHON 3.11.12 (Твоя ручная сборка)
RUN wget https://www.python.org/ftp/python/3.11.12/Python-3.11.12.tgz && \
    tar -xvf Python-3.11.12.tgz && \
    cd Python-3.11.12 && \
    ./configure --enable-optimizations --with-ensurepip=install --with-ssl && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.11.12 Python-3.11.12.tgz

RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python || true
RUN ln -s /usr/local/bin/pip3.11 /usr/local/bin/pip || true

# 4. PYTORCH NIGHTLY (Для 5090)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126

# 5. COMFYUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-cache

# 6. ЧИСТКА ЗАВИСИМОСТЕЙ (ГЛАВНОЕ!)
# Удаляем xformers и flash-attn из требований, чтобы они не скачались и не сломали 5090
RUN sed -i '/torch/d' /comfy-cache/requirements.txt
RUN sed -i '/xformers/d' /comfy-cache/requirements.txt
RUN sed -i '/flash-attn/d' /comfy-cache/requirements.txt

RUN pip install --no-cache-dir -r /comfy-cache/requirements.txt
# Возвращаем torchsde (нужен)
RUN pip install --no-cache-dir torchsde einops transformers

# 7. НОДЫ
RUN pip install jupyterlab
WORKDIR /comfy-cache/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 8. ЧИСТКА WAN WRAPPER
WORKDIR /comfy-cache/custom_nodes/ComfyUI-WanVideoWrapper
RUN sed -i '/torch/d' requirements.txt
RUN sed -i '/xformers/d' requirements.txt
RUN sed -i '/flash-attn/d' requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install imageio[ffmpeg] kornia protobuf sentencepiece huggingface_hub scipy

WORKDIR /workspace
COPY start.sh /start.sh
RUN chmod +x /start.sh
EXPOSE 3001 8888
CMD ["/start.sh"]
