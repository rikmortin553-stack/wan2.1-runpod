# ИСПОЛЬЗУЕМ САМУЮ СВЕЖУЮ СТАБИЛЬНУЮ СБОРКУ RUNPOD
# PyTorch 2.5.1 (новее) + CUDA 12.4 (стабильная база) + Python 3.11
FROM runpod/pytorch:2.5.1-py3.11-cuda12.4.1-devel-ubuntu22.04

# Рабочая директория
WORKDIR /workspace/ComfyUI

# 1. Системные пакеты (добавил libglib2.0-0, нужен для некоторых CV нод)
RUN apt-get update && apt-get install -y \
    git \
    wget \
    aria2 \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. Установка ComfyUI (фиксируем версию, чтобы не сломалось завтра)
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI

# 3. Обновляем pip и ставим зависимости ComfyUI
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /workspace/ComfyUI/requirements.txt

# 4. Установка обязательных нод: Manager и WanVideoWrapper
WORKDIR /workspace/ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 5. Установка тяжелых зависимостей для WanVideo
# Внимание: WanVideo требует специфических библиотек
WORKDIR /workspace/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper
RUN pip install --no-cache-dir -r requirements.txt

# Доустанавливаем специфические пакеты для Wan2.1 (video processing)
RUN pip install imageio[ffmpeg] kornia

# Возвращаемся в корень
WORKDIR /workspace

# 6. Скрипт запуска
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Порт для RunPod (чтобы он знал, что мы тут живы)
EXPOSE 3001

# Команда старта
CMD ["/start.sh"]
