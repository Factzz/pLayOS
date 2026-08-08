#!/bin/bash
LOG_FILE="/home/ark/playos-update.log"

echo ">> START UPDEATE PLAY OS WITH OTA..." | tee -a "$LOG_FILE"



if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS OTA Update\n\n Finish!"
fi


exit 187
