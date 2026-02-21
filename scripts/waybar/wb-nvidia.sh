# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

METRICS=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used --format=csv,noheader,nounits)
RAW_UTIL=$(echo "$METRICS" | cut -d',' -f1)
GPU_UTIL=$(echo "$RAW_UTIL" | sed 's/[^0-9]//g')
RAW_TEMP=$(echo "$METRICS" | cut -d',' -f2)
GPU_TEMP=$(echo "$RAW_TEMP" | sed 's/[^0-9]//g')
GPU_VRAM=$(echo "$METRICS" | cut -d',' -f3 | awk '{printf "%.1f", $1/1024}')

if [[ "$GPU_UTIL" =~ ^[0-9]+$ ]] && [ "$GPU_UTIL" -ge 80 ]; then
  GPU_COLOR="<span foreground='#e78284'>GPU ${RAW_UTIL}</span>"
elif [[ "$GPU_UTIL" =~ ^[0-9]+$ ]] && [ "$GPU_UTIL" -ge 50 ]; then
  GPU_COLOR="<span foreground='#e0d8a4'>GPU ${RAW_UTIL}</span>"
else
  GPU_COLOR="GPU ${RAW_UTIL}"
fi

if [[ "$GPU_TEMP" =~ ^[0-9]+$ ]] && [ "$GPU_TEMP" -ge 70 ]; then
  TEMP_COLOR="<span foreground='#e78284'>${RAW_TEMP}</span>"
elif [[ "$GPU_TEMP" =~ ^[0-9]+$ ]] && [ "$GPU_TEMP" -ge 50 ]; then
  TEMP_COLOR="<span foreground='#e0d8a4'>${RAW_TEMP}</span>"
else
  TEMP_COLOR="${RAW_TEMP}"
fi

echo "${GPU_COLOR}  VRAM ${GPU_VRAM} ${TEMP_COLOR}°"
