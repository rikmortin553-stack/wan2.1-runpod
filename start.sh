#!/bin/bash
set -e

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК RTX 5090 (FIXED ONNX CONFLICT)"
echo "----------------------------------------------------------------"

source /opt/venv/bin/activate
export TORCH_CUDA_ARCH_LIST="12.0"
export MAX_JOBS=$(nproc)

echo "🔑 Раздаю права..."
mkdir -p /workspace
chmod -R 777 /workspace

if ! python -c "import sageattention" 2>/dev/null; then
    echo "⚙️ Компилирую SageAttention..."
    cd /
    if [ -d "SageAttention" ]; then rm -rf SageAttention; fi
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    pip install . --no-build-isolation
    echo "✅ SageAttention готов!"
fi

if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "📦 Разворачиваю ComfyUI..."
    mkdir -p /workspace/ComfyUI
    rsync -a /comfy-build/ /workspace/ComfyUI/
    chmod -R 777 /workspace/ComfyUI
fi

NODES_DIR="/workspace/ComfyUI/custom_nodes"
mkdir -p "$NODES_DIR"

install_node() {
    url=$1
    folder=$2
    if [ ! -d "$NODES_DIR/$folder" ]; then
        echo "⬇️ Скачиваю: $folder..."
        git clone "$url" "$NODES_DIR/$folder"
        if [ -f "$NODES_DIR/$folder/requirements.txt" ]; then
            pip install -r "$NODES_DIR/$folder/requirements.txt" || true
        fi
    else
        echo "✅ $folder уже установлен."
    fi
}

echo "📦 Установка нод..."

install_node "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "ComfyUI-WanVideoWrapper"
install_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"
install_node "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_node "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git" "ComfyUI-WanAnimatePreprocess"
install_node "https://github.com/yolain/ComfyUI-Easy-Use.git" "ComfyUI-Easy-Use"

echo "🧹 Полная чистка ONNX во избежание конфликтов..."
pip uninstall -y onnxruntime onnxruntime-gpu || true

echo "🔧 Восстановление PyTorch для RTX 5090..."
pip install --upgrade --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

echo "📦 Чистая установка ONNX GPU и остальных библиотек..."
pip install "numpy<2" onnxruntime-gpu GitPython imageio-ffmpeg rembg matplotlib pandas ultralytics

MODELS="/workspace/ComfyUI/models"
echo "📂 Создаю папки моделей..."
mkdir -p "$MODELS/detection" "$MODELS/diffusion_models" "$MODELS/vae" "$MODELS/text_encoders" "$MODELS/clip_vision" "$MODELS/loras"
chmod -R 777 "$MODELS"

download_if_missing() {
    if [ ! -s "$1/$2" ]; then 
        echo "📥 Скачиваю $2..."
        aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"
        chmod 777 "$1/$2"
    fi
}

# Wan Models
download_if_missing "$MODELS/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_if_missing "$MODELS/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
download_if_missing "$MODELS/text_encoders" "umt5-xxl-enc-bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"
download_if_missing "$MODELS/clip_vision" "clip_vision_h.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

# Detection Models
download_if_missing "$MODELS/detection" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_if_missing "$MODELS/detection" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_if_missing "$MODELS/detection" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_if_missing "$MODELS/detection" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

# LoRA
download_if_missing "$MODELS/loras" "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "https://huggingface.co/dci05049/wan-animate/resolve/main/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

echo "🏁 Запускаю..."

cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --notebook-dir=/workspace --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True &

cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
