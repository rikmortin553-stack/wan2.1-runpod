#!/bin/bash
set -e

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК RTX 5090 (FIXED PATHS & JUPYTER ROOT)"
echo "----------------------------------------------------------------"

source /opt/venv/bin/activate
export TORCH_CUDA_ARCH_LIST="12.0"
export MAX_JOBS=$(nproc)

# 1. КОМПИЛЯЦИЯ SAGEATTENTION
if ! python -c "import sageattention" 2>/dev/null; then
    echo "⚙️ Компилирую SageAttention..."
    cd /workspace
    if [ -d "SageAttention" ]; then rm -rf SageAttention; fi
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    pip install . --no-build-isolation
    echo "✅ SageAttention готов!"
fi

# 2. Проверка ComfyUI
if [ ! -d "/workspace/ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi

# 3. Ноды
NODES_DIR="/workspace/ComfyUI/custom_nodes"
mkdir -p "$NODES_DIR"

if [ ! -d "$NODES_DIR/ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git "$NODES_DIR/ComfyUI-WanVideoWrapper"
fi

if [ ! -d "$NODES_DIR/ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$NODES_DIR/ComfyUI-Manager"
fi

# Зависимости нод
echo "📦 Ставлю зависимости нод..."
pip install -r "$NODES_DIR/ComfyUI-WanVideoWrapper/requirements.txt" || true
pip install -r "$NODES_DIR/ComfyUI-Manager/requirements.txt" || true
pip install onnxruntime-gpu GitPython

# 4. МОДЕЛИ И ПАПКИ (ИСПРАВЛЕНО)
MODELS="/workspace/ComfyUI/models"
# Создаем папку detection ЯВНО
mkdir -p "$MODELS/diffusion_models" "$MODELS/vae" "$MODELS/detection"

download_if_missing() {
    if [ ! -f "$1/$2" ]; then 
        echo "📥 Скачиваю $2 в $1..."
        aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"
    fi
}

# Основные модели
download_if_missing "$MODELS/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_if_missing "$MODELS/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

# Детекторы (ТЕПЕРЬ СКАЧИВАЮТСЯ В ПРАВИЛЬНУЮ ПАПКУ)
echo "📥 Проверка детекторов..."
download_if_missing "$MODELS/detection" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_if_missing "$MODELS/detection" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_if_missing "$MODELS/detection" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_if_missing "$MODELS/detection" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

# 5. Запуск
echo "🏁 Запускаю..."

# ИСПРАВЛЕНИЕ JUPYTER: Запуск от root в корне /workspace
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --notebook-dir=/ &

cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
