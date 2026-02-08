#!/bin/bash
set -e

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК RTX 5090 (FIXED ONNX & JUPYTER)"
echo "----------------------------------------------------------------"

source /opt/venv/bin/activate
export TORCH_CUDA_ARCH_LIST="12.0"
export MAX_JOBS=$(nproc)

# 1. КОМПИЛЯЦИЯ SAGEATTENTION (Если еще нет)
if ! python -c "import sageattention" 2>/dev/null; then
    echo "⚙️ Компилирую SageAttention (займет ~3 мин)..."
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

# 3. Ноды и зависимости
NODES_DIR="/workspace/ComfyUI/custom_nodes"
mkdir -p "$NODES_DIR"

# WanVideoWrapper
if [ ! -d "$NODES_DIR/ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git "$NODES_DIR/ComfyUI-WanVideoWrapper"
fi

# Preprocess Node (Тоже ставим, раз она в логах светилась)
if [ ! -d "$NODES_DIR/ComfyUI-WanAnimatePreprocess" ]; then
    git clone https://github.com/Wan-Video/ComfyUI-WanAnimatePreprocess.git "$NODES_DIR/ComfyUI-WanAnimatePreprocess" || true
fi

# Manager
if [ ! -d "$NODES_DIR/ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$NODES_DIR/ComfyUI-Manager"
fi

# !!! ВАЖНО: Принудительная установка зависимостей нод !!!
echo "📦 Устанавливаю зависимости нод..."
pip install -r "$NODES_DIR/ComfyUI-WanVideoWrapper/requirements.txt" || true
pip install -r "$NODES_DIR/ComfyUI-Manager/requirements.txt" || true
# Добиваем ONNX вручную, чтобы наверняка
pip install onnxruntime-gpu GitPython

# 4. Модели (Минимум)
MODELS="/workspace/ComfyUI/models"
mkdir -p "$MODELS/diffusion_models" "$MODELS/vae" 

download_if_missing() {
    if [ ! -f "$1/$2" ]; then aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"; fi
}
download_if_missing "$MODELS/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_if_missing "$MODELS/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

# 5. Запуск
echo "🏁 Запускаю..."

# ИСПРАВЛЕНИЕ JUPYTER: Явно переходим в workspace и разрешаем root
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --notebook-dir=/workspace &

cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
