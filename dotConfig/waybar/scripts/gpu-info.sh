#!/bin/bash
GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

# Choose icon based on utilization level (optional)
case $GPU_UTIL in
[0-9]) ICON="󰝦" ;;        # 0-9%
[1-2][0-9]) ICON="󰪞" ;;   # 10-29%
[3-4][0-9]) ICON="󰪟" ;;   # 30-49%
[5-6][0-9]) ICON="󰪣" ;;   # 50-69%
[7-8][0-9]) ICON="󰪤" ;;   # 70-89%
9[0-4]) ICON="󰪥" ;;       # 90-94%
9[5-9] | 100) ICON="󰪢" ;; # 95-100%
*) ICON="󰪠" ;;            # Default
esac

echo $ICON $GPU_UTIL
