# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

METRICS=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used --format=csv,noheader,nounits)
RAW_UTIL=$(echo "$METRICS" | cut -d',' -f1)
GPU_UTIL=$(echo "$RAW_UTIL" | sed 's/[^0-9]//g')
GPU_TEMP=$(echo "$METRICS" | cut -d',' -f2 | tr -d ' °C')
GPU_VRAM=$(echo "$METRICS" | cut -d',' -f3 | awk '{printf "%.1f", $1/1024}')

UTIL_STATE="normal"
TEMP_STATE="normal"

if [[ "$GPU_UTIL" =~ ^[0-9]+$ ]] && [ "$GPU_UTIL" -ge 80 ]; then
  UTIL_STATE="critical"
elif [[ "$GPU_UTIL" =~ ^[0-9]+$ ]] && [ "$GPU_UTIL" -ge 50 ]; then
  UTIL_STATE="warning"
fi

if [ "$GPU_TEMP" -ge 70 ] 2>/dev/null; then
  TEMP_STATE="critical"
elif [ "$GPU_TEMP" -ge 50 ] 2>/dev/null; then
  TEMP_STATE="warning"
fi

case "${UTIL_STATE}${TEMP_STATE}" in
*critical*)
  echo "<span foreground='#E0AEA4'>GPU ${RAW_UTIL}</span>  VRAM ${GPU_VRAM}  <span foreground='#E0AEA4'>${GPU_TEMP}°</span>"
  ;;
*warning*)
  echo "<span foreground='#e0d8a4'>GPU ${RAW_UTIL}</span>  VRAM ${GPU_VRAM}  <span foreground='#e0d8a4'>${GPU_TEMP}°</span>"
  ;;
*)
  echo "GPU ${RAW_UTIL} VRAM ${GPU_VRAM} ${GPU_TEMP}°"
  ;;
esac
