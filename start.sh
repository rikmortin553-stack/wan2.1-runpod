#!/bin/bash

# Остановка при ошибках
set -e

echo "🚀 Начинаем проверку и загрузку моделей..."

# Базовая папка моделей
BASE_DIR="/workspace/ComfyUI/models"

# Функция для скачивания (если файл не существует)
download_if_missing() {
    local dir="$1"
    local file="$2"
    local url="$3"
    
    mkdir -p "$dir"
    if [ ! -f "$dir/$file" ]; then
        echo "📥 Скачиваю $file в $dir..."
        # Используем aria2c для скорости (16 потоков)
        aria2c -x 16 -s 16 -k 1M -d "$dir" -o "$file" "$url"
    else
        echo "✅ $file уже существует, пропускаем."
    fi
}

# --- 1. Diffusion Model ---
download_if_missing "$BASE_DIR/diffusion_models" \
    "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" \
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"

# --- 2. LoRA ---
download_if_missing "$BASE_DIR/loras" \
    "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
    "https://huggingface.co/dci05049/wan-animate/resolve/main/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

# --- 3. CLIP Vision ---
download_if_missing "$BASE_DIR/clip_vision" \
    "clip_vision_h.safetensors" \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

# --- 4. VAE ---
download_if_missing "$BASE_DIR/vae" \
    "Wan2_1_VAE_bf16.safetensors" \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

# --- 5. CLIP (Text Encoder) ---
# Обычно UMT5 кладется в text_encoders или clip, проверим путь для WanWrapper
download_if_missing "$BASE_DIR/text_encoders" \
    "umt5-xxl-enc-bf16.safetensors" \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"

# --- 6. Detection / ONNX (Для VitPose и YOLO) ---
# WanVideoWrapper обычно ищет их в models/onnx или ultralytics
# Скачаем в папку onnx (универсально) и detection (как просили)
DETECT_DIR="$BASE_DIR/onnx"

download_if_missing "$DETECT_DIR" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_if_missing "$DETECT_DIR" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_if_missing "$DETECT_DIR" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_if_missing "$DETECT_DIR" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

echo "🎉 Все готово! Запускаем ComfyUI на порту 3001..."

# Запуск ComfyUI
cd /workspace/ComfyUI
# Запускаем с listen (доступ извне) и указанным портом
python main.py --listen 0.0.0.0 --port 3001
