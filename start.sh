#!/bin/bash
set +e 
echo "🚀 ЗАПУСК RTX 5090 (FINAL FIX)"

# 1. Восстанавливаем ComfyUI
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    rsync -a /comfy-cache/ /workspace/ComfyUI/
fi

# 2. ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ НОД
# Это решает проблему "Red Nodes / Missing Nodes"
echo "♻️ Заменяем папку WanVideoWrapper на новую..."
rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper
cp -r /comfy-cache/custom_nodes/ComfyUI-WanVideoWrapper /workspace/ComfyUI/custom_nodes/
pip install -r /workspace/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt > /dev/null 2>&1

echo "🔍 Жду GPU..."
while ! nvidia-smi > /dev/null 2>&1; do sleep 2; done

# --- ЗАГРУЗКА ---
BASE_DIR="/workspace/ComfyUI/models"
download_missing() {
    mkdir -p "$1"
    if [ ! -f "$1/$2" ]; then aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"; fi
}

download_missing "$BASE_DIR/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_missing "$BASE_DIR/loras" "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "https://huggingface.co/dci05049/wan-animate/resolve/main/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
download_missing "$BASE_DIR/clip_vision" "clip_vision_h.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
download_missing "$BASE_DIR/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
download_missing "$BASE_DIR/text_encoders" "umt5-xxl-enc-bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"

DET_DIR="$BASE_DIR/detection"
download_missing "$DET_DIR" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_missing "$DET_DIR" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_missing "$DET_DIR" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_missing "$DET_DIR" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

echo "🏁 ЗАПУСК..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' > /dev/null 2>&1 &

cd /workspace/ComfyUI
# Запускаем без флагов disable, так как мы будем решать проблему в UI
python -u main.py --listen 0.0.0.0 --port 3001 --highvram
