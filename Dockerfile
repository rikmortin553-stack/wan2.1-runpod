# Версия 2.4.0 (Стабильная и рабочая)
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Включаем мгновенные логи
ENV PYTHONUNBUFFERED=1 

WORKDIR /

# 1. Системные пакеты (добавил rsync для восстановления файлов)
RUN apt-get update && apt-get install -y \
    git wget aria2 ffmpeg libgl1-mesa-glx libglib2.0-0 rsync \
    && rm -rf /var/lib/apt/lists/*

# 2. Клонируем ComfyUI в КЭШ (защита от перезаписи диском)
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-cache

# 3. Ставим зависимости
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /comfy-cache/requirements.txt

# 4. Ноды
WORKDIR /comfy-cache/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git

# 5. Зависимости нод
WORKDIR /comfy-cache/custom_nodes/ComfyUI-WanVideoWrapper
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install imageio[ffmpeg] kornia

WORKDIR /workspace

# 6. Скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3001
EXPOSE 8888

CMD ["/start.sh"]
