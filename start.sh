#!/bin/bash
set +e 

echo "----------------------------------------------------------------"
echo "🚀 ЗАПУСК RTX 5090 (SAFE MODE)"
echo "----------------------------------------------------------------"

if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    rsync -a /comfy-cache/ /workspace/ComfyUI/
fi

echo "🔍 Проверяю GPU..."
while ! nvidia-smi > /dev/null 2>&1; do sleep 2; done

# --- ЗАГРУЗКА ФАЙЛОВ ---
BASE_DIR="/workspace/ComfyUI/models"
download_big() {
    mkdir -p "$1"
    if [ ! -f "$1/$2" ]; then aria2c -x 16 -s 16 -k 1M -d "$1" -o "$2" "$3"; fi
}
download_safe() {
    mkdir -p "$1"
    if [ ! -f "$1/$2" ]; then wget -O "$1/$2" "$3"; fi
}

download_big "$BASE_DIR/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_big "$BASE_DIR/loras" "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "https://huggingface.co/dci05049/wan-animate/resolve/main/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

download_safe "$BASE_DIR/clip_vision" "clip_vision_h.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
download_safe "$BASE_DIR/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
download_safe "$BASE_DIR/text_encoders" "umt5-xxl-enc-bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"

DET_DIR="$BASE_DIR/detection"
if [ ! -d "$DET_DIR" ]; then mkdir -p "$DET_DIR"; fi
download_safe "$DET_DIR" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_safe "$DET_DIR" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_safe "$DET_DIR" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_safe "$DET_DIR" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

echo "🏁 ЗАПУСК..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' > /dev/null 2>&1 &

cd /workspace/ComfyUI
# ВАЖНО: Добавлен флаг --disable-xformers
python -u main.py --listen 0.0.0.0 --port 3001 --highvram --disable-xformers
