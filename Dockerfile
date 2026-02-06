# База RunPod (Ubuntu 22.04)
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Логи без задержек
ENV PYTHONUNBUFFERED=1 

WORKDIR /

# 1. Системные пакеты (добавил libgoogle-perftools4 для оптимизации памяти)
RUN apt-get update && apt-get install -y \
    git wget aria2 ffmpeg libgl1-mesa-glx libglib2.0-0 rsync libgoogle-perftools4 \
    && rm -rf /var/lib/apt/lists/*

# --- ОБНОВЛЕНИЕ ДЛЯ RTX 5090 ---
# Удаляем старый PyTorch
RUN pip uninstall -y torch torchvision torchaudio text-generation
# Ставим Nightly Build cu126 (Это самая стабильная версия для 5090 на сегодня)
# Она прекрасно работает на драйвере 12.8
RUN pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu126
# -------------------------------

# 2. Клонируем ComfyUI в кэш
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-cache

# 3. Ставим зависимости ComfyUI
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /comfy-cache/requirements.txt

# 4. Кастомные ноды (Все из твоего workflow)
WORKDIR /comfy-cache/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 5. Зависимости для WanVideo и фиксы
WORKDIR /comfy-cache/custom_nodes/ComfyUI-WanVideoWrapper
RUN pip install --no-cache-dir -r requirements.txt
# Добавляем важные библиотеки, чтобы не было ошибок импорта
RUN pip install imageio[ffmpeg] kornia protobuf sentencepiece huggingface_hub

WORKDIR /workspace

# 6. Скрипт запуска
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3001
EXPOSE 8888

CMD ["/start.sh"]
