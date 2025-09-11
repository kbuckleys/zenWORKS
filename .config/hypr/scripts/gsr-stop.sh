#!/bin/bash
notify-send "Recording Stopped" "GPU Screen Recorder"
pkill -SIGINT -f gpu-screen-recorder
