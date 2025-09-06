#!/bin/bash
GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

# Choose icon based on utilization level (optional)
case $GPU_UTIL in
*) ICON="GPU" ;; # Default
esac

echo $ICON $GPU_UTIL
