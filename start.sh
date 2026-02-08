#!/bin/bash
set -e

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК NVIDIA BLACKWELL (RTX 5090) - CODE FROM DOCS"
echo "----------------------------------------------------------------"

# Настройки путей
WORKSPACE="/workspace"
COMFY_DIR="$WORKSPACE/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
VENV_DIR="/opt/venv"

# 1. Активация виртуального окружения (где лежат наши скомпилированные либы)
source "$VENV_DIR/bin/activate"

# 2. Диагностика (Чтобы ты был спокоен)
echo ">>> System Check:"
echo " Python: $(python --version)"
echo " Torch: $(python -c 'import torch; print(torch.__version__)')"
echo " CUDA Available: $(python -c 'import torch; print(torch.cuda.is_available())')"
echo " Arch List: $(python -c 'import torch; print(torch.cuda.get_arch_list())')" 

# 3. Установка/Обновление ComfyUI
if [ ! -d "$COMFY_DIR" ]; then
    echo ">>> ComfyUI not found. Cloning..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
else
    echo ">>> ComfyUI found. Pulling updates..."
    cd "$COMFY_DIR"
    git pull
fi

# 4. Установка зависимостей с ЗАЩИТОЙ
echo ">>> Installing dependencies (Safe Mode)..."
cd "$COMFY_DIR"
# Создаем safe-файл, исключая torch, чтобы pip не сломал нашу nightly-сборку
grep -vE "torch|torchvision|torchaudio" requirements.txt > requirements_safe.txt
pip install -r requirements_safe.txt

# 5. Установка WanVideoWrapper (Kijai)
mkdir -p "$CUSTOM_NODES"
if [ ! -d "$CUSTOM_NODES/ComfyUI-WanVideoWrapper" ]; then
    echo ">>> Installing WanVideoWrapper..."
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git "$CUSTOM_NODES/ComfyUI-WanVideoWrapper"
    cd "$CUSTOM_NODES/ComfyUI-WanVideoWrapper"
    # Тоже фильтруем torch
    grep -vE "torch|torchvision|torchaudio|sageattention" requirements.txt > requirements_safe.txt
    pip install -r requirements_safe.txt
else
    echo ">>> Updating WanVideoWrapper..."
    cd "$CUSTOM_NODES/ComfyUI-WanVideoWrapper"
    git pull
    grep -vE "torch|torchvision|torchaudio|sageattention" requirements.txt > requirements_safe.txt
    pip install -r requirements_safe.txt
fi

# Установка Manager
if [ ! -d "$CUSTOM_NODES/ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$CUSTOM_NODES/ComfyUI-Manager"
fi

# 6. Загрузка моделей (Базовая, чтобы ты мог начать)
# Я добавил проверку, чтобы не качать каждый раз
MODEL_PATH="$COMFY_DIR/models"
mkdir -p "$MODEL_PATH/diffusion_models" "$MODEL_PATH/text_encoders" "$MODEL_PATH/vae" "$MODEL_PATH/clip_vision"

# Функция безопасной загрузки
download_file() {
    if [ ! -f "$1/$2" ]; then
        echo "📥 Downloading $2..."
        aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"
    fi
}

# Wan 2.1 Models (Ссылки из твоего прошлого запроса)
download_file "$MODEL_PATH/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_file "$MODEL_PATH/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
download_file "$MODEL_PATH/text_encoders" "umt5-xxl-enc-bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"
download_file "$MODEL_PATH/clip_vision" "clip_vision_h.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

# 7. Запуск
echo ">>> Launching ComfyUI on Port 3000 (Proxy Compatible)..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' > /dev/null 2>&1 &

cd "$COMFY_DIR"
# Используем --gpu-only согласно рекомендации документа №2 для 5090
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
