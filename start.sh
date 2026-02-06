#!/bin/bash

# Не падать при мелких ошибках
set +e 

echo "----------------------------------------------------------------"
echo "🛠️ ЗАПУСК КОНТЕЙНЕРА (VER 5.0 - DETECTION FIX)"
echo "----------------------------------------------------------------"

# --- 1. ЛЕЧЕНИЕ ComfyUI (Исправляем ошибку main.py not found) ---
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "⚠️ Внимание: ComfyUI не найден в рабочей папке (перекрыт диском)!"
    echo "♻️ Восстанавливаю файлы из кэша..."
    # Копируем файлы движка, но не трогаем твои модели
    rsync -a /comfy-cache/ /workspace/ComfyUI/
    echo "✅ ComfyUI успешно восстановлен!"
else
    echo "✅ Файлы ComfyUI на месте."
fi

# --- 2. ОЖИДАНИЕ GPU (Чтобы Python не падал) ---
echo "🔍 Проверяю видеокарту..."
while ! nvidia-smi > /dev/null 2>&1; do
    echo "⏳ Жду драйвер NVIDIA... (sleep 2)"
    sleep 2
done
echo "✅ Видеокарта готова!"

# --- НАСТРОЙКИ ЗАГРУЗКИ ---
BASE_DIR="/workspace/ComfyUI/models"

# Функция быстрой загрузки
download_big() {
    local dir="$1"
    local file="$2"
    local url="$3"
    mkdir -p "$dir"
    if [ ! -f "$dir/$file" ]; then
        echo "📥 [ARIA2] Скачиваю $file..."
        aria2c -x 16 -s 16 -k 1M -d "$dir" -o "$file" "$url"
    else
        echo "✅ $file OK"
    fi
}

# Функция надежной загрузки
download_safe() {
    local dir="$1"
    local file="$2"
    local url="$3"
    mkdir -p "$dir"
    if [ ! -f "$dir/$file" ]; then
        echo "📥 [WGET] Скачиваю $file..."
        wget -O "$dir/$file" "$url"
    else
        echo "✅ $file OK"
    fi
}

echo "📂 Проверка основных моделей..."
download_big "$BASE_DIR/diffusion_models" "Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
download_big "$BASE_DIR/loras" "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "https://huggingface.co/dci05049/wan-animate/resolve/main/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

download_safe "$BASE_DIR/clip_vision" "clip_vision_h.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
download_safe "$BASE_DIR/vae" "Wan2_1_VAE_bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
download_safe "$BASE_DIR/text_encoders" "umt5-xxl-enc-bf16.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"

# --- DETECTION BLOCK (Специально для тебя) ---
echo "----------------------------------------------------------------"
echo "📂 ПОДГОТОВКА ПАПКИ DETECTION..."
DET_DIR="$BASE_DIR/detection"

# ЯВНОЕ СОЗДАНИЕ ПАПКИ
if [ ! -d "$DET_DIR" ]; then
    echo "🔨 Папки нет. Создаю: $DET_DIR"
    mkdir -p "$DET_DIR"
else
    echo "👌 Папка detection уже есть."
fi

# Скачивание файлов
download_safe "$DET_DIR" "yolov10m.onnx" "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
download_safe "$DET_DIR" "vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
download_safe "$DET_DIR" "vitpose_h_wholebody_model.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
download_safe "$DET_DIR" "vitpose-l-wholebody.onnx" "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx"

echo "----------------------------------------------------------------"
echo "🏁 ЗАПУСК..."

# Запуск Jupyter
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' &

# Запуск ComfyUI
cd /workspace/ComfyUI
python -u main.py --listen 0.0.0.0 --port 3001
