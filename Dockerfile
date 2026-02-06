# 1. СТРОГО CUDA 12.8.1 (как ты просил)
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1 
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

WORKDIR /

# 2. ПОДГОТОВКА К СБОРКЕ PYTHON
# Ставим библиотеки, необходимые для компиляции Python из исходников
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libnss3-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    git wget aria2 ffmpeg libgl1-mesa-glx libglib2.0-0 rsync curl \
    && rm -rf /var/lib/apt/lists/*

# 3. КОМПИЛЯЦИЯ PYTHON 3.11.12 (ТОЧНАЯ ВЕРСИЯ)
# Скачиваем исходники именно 3.11.12 и собираем
RUN wget https://www.python.org/ftp/python/3.11.12/Python-3.11.12.tgz && \
    tar -xvf Python-3.11.12.tgz && \
    cd Python-3.11.12 && \
    ./configure --enable-optimizations --with-ensurepip=install && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.11.12 Python-3.11.12.tgz

# Проверяем, что python3 указывает куда надо
RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python || true
RUN ln -s /usr/local/bin/pip3.11 /usr/local/bin/pip || true

# 4. УСТАНОВКА PYTORCH (ДЛЯ 5090)
# Используем Nightly cu126 (совместим с CUDA 12.8 и RTX 5090)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126

# 5. УСТАНОВКА COMFYUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-cache

# 6. ЗАВИСИМОСТИ (С ЗАЩИТОЙ ОТ DOWNGRADE)
# Вырезаем torch из зависимостей, чтобы ComfyUI не поставил старую версию
RUN sed -i '/torch/d' /comfy-cache/requirements.txt
RUN pip install --no-cache-dir -r /comfy-cache/requirements.txt

# 7. JUPYTER И НОДЫ
RUN pip install jupyterlab

WORKDIR /comfy-cache/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 8. ЗАВИСИМОСТИ WAN (ЗАЩИТА ОТ DOWNGRADE)
WORKDIR /comfy-cache/custom_nodes/ComfyUI-WanVideoWrapper
RUN sed -i '/torch/d' requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install imageio[ffmpeg] kornia protobuf sentencepiece huggingface_hub

WORKDIR /workspace

# 9. ЗАПУСК
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3001
EXPOSE 8888

CMD ["/start.sh"]
