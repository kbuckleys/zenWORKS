#!/bin/bash
GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
echo "$GPU_TEMP°C"
