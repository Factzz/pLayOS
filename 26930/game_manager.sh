#!/bin/bash
ACTION=$1
FILE_PATH=$2

if [ "$ACTION" == "uninstall" ]; then
    # 1. แยกส่วนประกอบของไฟล์
    ROM_DIR=$(dirname "$FILE_PATH")
    FILENAME=$(basename "$FILE_PATH")
    EXTENSION="${FILENAME##*.}"
    BASENAME="${FILENAME%.*}"
    SYSTEM_NAME=$(basename "$ROM_DIR")

    # เซฟตี้กันเหนียว ห้ามรันถ้าไม่มีชื่อไฟล์
    if [ -z "$BASENAME" ] || [ -z "$FILENAME" ] || [ "$BASENAME" == "*" ]; then
        exit 1
    fi

    # ==========================================
    # 2. ท่าไม้ตายจัดการเกม PORTMASTER
    # ==========================================
    if [ "$SYSTEM_NAME" == "ports" ] && [ "$EXTENSION" == "sh" ]; then
        
        # แบบที่ 1: ชื่อโฟลเดอร์ตรงกับชื่อไฟล์ .sh เป๊ะๆ
        if [ -n "$BASENAME" ] && [ -d "$ROM_DIR/$BASENAME" ]; then
            rm -rf "$ROM_DIR/$BASENAME"
        fi
        
        # แบบที่ 2: "ล้วงเข้าไปอ่านในไฟล์ .sh" แบบที่ลูกพี่สั่ง!
        # สกัดเอาคำทุกคำในไฟล์ .sh ออกมา แล้วเช็คทีละคำเลยว่ามันคือโฟลเดอร์เกมไหม
        WORDS=$(grep -oE '[a-zA-Z0-9_\-]+' "$FILE_PATH" | sort -u)
        for WORD in $WORDS; do
            # ระบบป้องกัน: ข้ามคำสงวน และห้ามลบโฟลเดอร์ระบบเด็ดขาด!
            if [[ "${WORD,,}" == "portmaster" || "${WORD,,}" == "images" || "${WORD,,}" == "videos" || "${WORD,,}" == "roms" || "${WORD,,}" == "ports" || "${WORD,,}" == "cd" || "${WORD,,}" == "sh" || "${WORD,,}" == "sudo" ]]; then
                continue
            fi
            
            # ถ้าคำที่เจอในสคริปต์ ดันไปตรงกับ "โฟลเดอร์" ที่มีอยู่จริง = ระเบิดทิ้ง!
            if [ -d "$ROM_DIR/$WORD" ]; then
                rm -rf "$ROM_DIR/$WORD"
            fi
        done
    fi

    # ==========================================
    # 3. ลบไฟล์เกมหลัก (รอม หรือ .sh)
    # ==========================================
    rm -f "$FILE_PATH"

    # ==========================================
    # 4. ลบไฟล์เซฟแบบขุดรากถอนโคน
    # ==========================================
    # เซฟที่อยู่ในโฟลเดอร์เดียวกับรอม
    find "$ROM_DIR" -maxdepth 1 -type f \( -name "${BASENAME}.srm" -o -name "${BASENAME}.state*" -o -name "${BASENAME}.sav" -o -name "${BASENAME}.rtc" -o -name "${FILENAME}.srm" \) -exec rm -f {} \;
    
    # เซฟที่ถูกแยกไปเก็บในโฟลเดอร์ระบบ (ถ้ามี)
    for SAVE_DIR in "/roms/savestates/${SYSTEM_NAME}" "/roms/saves/${SYSTEM_NAME}"; do
        if [ -d "$SAVE_DIR" ]; then
            find "$SAVE_DIR" -maxdepth 1 -type f \( -name "${BASENAME}.*" -o -name "${FILENAME}.*" \) -exec rm -f {} \;
        fi
    done

    # ==========================================
    # 5. ลบไฟล์ MEDIA (ภาพปก, วิดีโอ) กวาดเรียบทุกรูปแบบ
    # ==========================================
    for MEDIA_DIR in "$ROM_DIR/images" "$ROM_DIR/videos" "$ROM_DIR/downloaded_images" "$ROM_DIR/media"; do
        if [ -d "$MEDIA_DIR" ]; then
            # กวาดล้างทั้งแบบไม่มีนามสกุลรอม และมีนามสกุลรอมติดมาด้วย
            find "$MEDIA_DIR" -type f \( -name "${BASENAME}.*" -o -name "${BASENAME}-*" -o -name "${FILENAME}.*" -o -name "${FILENAME}-*" \) -exec rm -f {} \;
        fi
    done

    exit 0
fi