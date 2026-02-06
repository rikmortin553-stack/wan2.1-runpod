# 1. СТРОГО CUDA 12.8.1 (База от NVIDIA)
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1 
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

WORKDIR /

# 2. УСТАНОВКА ВСЕХ ЗАВИСИМОСТЕЙ ДЛЯ СБОРКИ PYTHON
# Я включил сюда вообще всё, что может понадобиться, чтобы не было ошибок "No module named X"
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libnss3-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    liblzma-dev \
    libgdbm-dev \
    libc6-dev \
    uuid-dev \
    tk-dev \
    git wget aria2 ffmpeg libgl1-mesa-glx libglib2.0-0 rsync curl \
    && rm -rf /var/lib/apt/lists/*

# 3. КОМПИЛЯЦИЯ PYTHON 3.11.12 (С ВКЛЮЧЕННЫМИ МОДУЛЯМИ)
RUN wget https://www.python.org/ftp/python/3.11.12/Python-3.11.12.tgz && \
    tar -xvf Python-3.11.12.tgz && \
    cd Python-3.11.12 && \
    ./configure --enable-optimizations --with-ensurepip=install --with-ssl && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.11.12 Python-3.11.12.tgz

# Создаем ссылки, чтобы система видела новый питон
RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python || true
RUN ln -s /usr/local/bin/pip3.11 /usr/local/bin/pip || true

# 4. УСТАНОВКА PYTORCH (NIGHTLY ДЛЯ RTX 5090)
# Ставим версию cu126, она единственная работает на Blackwell (5090)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126

# 5. УСТАНОВКА COMFYUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-cache

# 6. УСТАНОВКА ЗАВИСИМОСТЕЙ (С ВОССТАНОВЛЕНИЕМ УДАЛЕННЫХ)
# Шаг А: Удаляем упоминания torch из файла требований, чтобы pip не скачал старую версию
RUN sed -i '/torch/d' /comfy-cache/requirements.txt
# Шаг Б: Ставим всё остальное (numpy, pillow...)
RUN pip install --no-cache-dir -r /comfy-cache/requirements.txt
# Шаг В: ВРУЧНУЮ возвращаем torchsde, который мы удалили (он нужен для Comfy)
# Также добавляем einops и transformers, они нужны для Wan
RUN pip install --no-cache-dir torchsde einops transformers

# 7. УСТАНОВКА JUPYTER И НОД
RUN pip install jupyterlab
WORKDIR /comfy-cache/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 8. ЗАВИСИМОСТИ WAN VIDEO
WORKDIR /comfy-cache/custom_nodes/ComfyUI-WanVideoWrapper
# Опять чистим torch, чтобы не сломать сборку
RUN sed -i '/torch/d' requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
# Добиваем библиотеки, которых может не хватать
RUN pip install imageio[ffmpeg] kornia protobuf sentencepiece huggingface_hub scipy

WORKDIR /workspace

# 9. ФИНАЛ
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3001
EXPOSE 8888

CMD ["/start.sh"]
