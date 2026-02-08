#!/bin/bash
set -e

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК RTX 5090 (FIXED PERMISSIONS & JUPYTER)"
echo "----------------------------------------------------------------"

source /opt/venv/bin/activate
export TORCH_CUDA_ARCH_LIST="12.0"
export MAX_JOBS=$(nproc)

# 0. ИСПРАВЛЕНИЕ ПРАВ (ЧТОБЫ ТЫ МОГ РЕДАКТИРОВАТЬ ФАЙЛЫ)
echo "🔑 Выдаю права на папку workspace..."
mkdir -p /workspace
chmod -R 777 /workspace

# 1. КОМПИЛЯЦИЯ SAGEATTENTION
if ! python -c "import sageattention" 2>/dev/null; then
    echo "⚙️ Компилирую SageAttention..."
    cd /
    if [ -d "SageAttention" ]; then rm -rf SageAttention; fi
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    pip install . --no-build-isolation
    echo "✅ SageAttention готов!"
fi

# 2. ВОССТАНОВЛЕНИЕ COMFYUI
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "📦 Копирую ComfyUI на диск..."
    mkdir -p /workspace/ComfyUI
    rsync -a /comfy-build/ /workspace/ComfyUI/
    chmod -R 777 /workspace/ComfyUI
fi

# 3. МОДЕЛИ (ПРИНУДИТЕЛЬНОЕ СОЗДАНИЕ ПАПОК)
MODELS="/workspace/ComfyUI/models"
echo "📂 Создаю структуру папок..."
mkdir -p "$MODELS/diffusion_models" 
mkdir -p "$MODELS/vae" 
mkdir -p "$MODELS/detection" # ЯВНО СОЗДАЕМ
chmod -R 777 "$MODELS" # ДАЕМ ПРАВА

download_if_missing() {
    # Проверяем файл. Если его нет ИЛИ он пустой (0 байт) - качаем
    if [ ! -s "$1/$2" ]; then 
        echo "📥 Скачиваю $2..."
        aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"
        chmod 777 "$1/$2"
    else
        echo "✅ $2 существует."
    fi
}

# Wan Models
download_if_missing "$MODELS/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_if_missing "$MODELS/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

# Detection Models
download_if_missing "$MODELS/detection" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_if_missing "$MODELS/detection" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_if_missing "$MODELS/detection" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_if_missing "$MODELS/detection" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

# 4. ЗАПУСК
echo "🏁 Запускаю..."

# JUPYTER: Добавлены флаги отключения защиты Origin и XSRF
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --notebook-dir=/workspace --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True &

cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
