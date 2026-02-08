#!/bin/bash
set -e

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК RTX 5090 (RUNTIME COMPILATION MODE)"
echo "----------------------------------------------------------------"

# Настройка окружения
source /opt/venv/bin/activate
export TORCH_CUDA_ARCH_LIST="12.0"
# Используем все ядра RunPod для быстрой компиляции
export MAX_JOBS=$(nproc)

# 1. ПРОВЕРКА И КОМПИЛЯЦИЯ SAGEATTENTION
# Это выполнится только один раз при старте
if ! python -c "import sageattention" 2>/dev/null; then
    echo "⚙️ SageAttention не найден. Компилирую под RTX 5090..."
    echo "⏳ Это займет 2-4 минуты. Не паникуй, это нормально..."
    
    cd /workspace
    if [ -d "SageAttention" ]; then rm -rf SageAttention; fi
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    
    # Самый важный момент: компиляция под sm_120
    pip install . --no-build-isolation
    
    echo "✅ SageAttention успешно скомпилирован!"
else
    echo "✅ SageAttention уже установлен."
fi

# 2. Установка/Обновление ComfyUI
if [ ! -d "/workspace/ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi

# 3. Установка WanVideoWrapper (Ноды)
NODES_DIR="/workspace/ComfyUI/custom_nodes"
mkdir -p "$NODES_DIR"

if [ ! -d "$NODES_DIR/ComfyUI-WanVideoWrapper" ]; then
    echo "📦 Скачиваю WanVideo ноды..."
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git "$NODES_DIR/ComfyUI-WanVideoWrapper"
    cd "$NODES_DIR/ComfyUI-WanVideoWrapper"
    # Удаляем sageattention из требований, так как мы его уже скомпилировали вручную
    sed -i '/sageattention/d' requirements.txt
    pip install -r requirements.txt
fi

if [ ! -d "$NODES_DIR/ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$NODES_DIR/ComfyUI-Manager"
fi

# 4. Загрузка моделей (Минимальный набор)
MODELS="/workspace/ComfyUI/models"
mkdir -p "$MODELS/diffusion_models" "$MODELS/vae" "$MODELS/text_encoders" "$MODELS/clip_vision"

download_if_missing() {
    if [ ! -f "$1/$2" ]; then
        echo "📥 Скачиваю $2..."
        aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"
    fi
}

download_if_missing "$MODELS/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_if_missing "$MODELS/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

# 5. Запуск
echo "🏁 Запускаю ComfyUI..."
cd /workspace/ComfyUI
# Запускаем Jupyter на фоне
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' &

# Запускаем Comfy
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
