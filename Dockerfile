# Используем стабильную версию 2.4.0 (она точно есть в реестре)
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Рабочая директория
WORKDIR /workspace/ComfyUI

# 1. Системные пакеты
RUN apt-get update && apt-get install -y \
    git \
    wget \
    aria2 \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. Установка ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI

# 3. Обновляем pip и ставим зависимости ComfyUI
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /workspace/ComfyUI/requirements.txt

# 4. Установка обязательных нод
WORKDIR /workspace/ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 5. Установка тяжелых зависимостей
WORKDIR /workspace/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install imageio[ffmpeg] kornia

# Возвращаемся в корень
WORKDIR /workspace

# 6. Скрипт запуска
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ОТКРЫВАЕМ ПОРТЫ: 3001 (Comfy) и 8888 (Jupyter)
EXPOSE 3001
EXPOSE 8888

# Команда старта
CMD ["/start.sh"]
