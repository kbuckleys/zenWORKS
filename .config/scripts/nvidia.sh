# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

METRICS=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used --format=csv,noheader,nounits)
GPU_UTIL=$(echo "$METRICS" | cut -d',' -f1)
GPU_TEMP=$(echo "$METRICS" | cut -d',' -f2)
GPU_VRAM=$(echo "$METRICS" | cut -d',' -f3)

if [ "$GPU_TEMP" -ge 70 ]; then
  echo "GPU $GPU_UTIL%  VRAM${GPU_VRAM} MB \033[38;2;224;174;164m${GPU_TEMP}°C\033[0m"
else
  echo "GPU $GPU_UTIL%  VRAM${GPU_VRAM} MB ${GPU_TEMP}°C"
fi
