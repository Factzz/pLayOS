#!/bin/bash

# ตรวจสอบและขอสิทธิ์ Root แอดมินเพื่อแก้ไขระบบ
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

printf "\033c" > /dev/tty1
echo "=========================================" > /dev/tty1
echo "        PLAY OS - NDS Save Fixer         " > /dev/tty1
echo "=========================================" > /dev/tty1
echo "" > /dev/tty1
echo ">>> กำลังดำเนินการแก้ไขบั๊ก NDS ค้างตอนเซฟ..." > /dev/tty1
sleep 1

# 1. คืนกรรมสิทธิ์โฟลเดอร์อีมูเลเตอร์ Drastic ให้ผู้เล่น (ark)
chown -R ark:ark /opt/drastic 2>/dev/null
chown -R ark:ark /opt/advanceddrastic 2>/dev/null

# 2. ตรวจสอบและสร้างโฟลเดอร์เซฟเกมในเมมโมรี่การ์ด (รองรับทั้งเมม 1 และเมม 2)
for rom_path in /roms /roms2; do
    if [ -d "$rom_path/nds" ]; then
        mkdir -p "$rom_path/nds/backup"
        mkdir -p "$rom_path/nds/savestates"
        chown -R ark:ark "$rom_path/nds" 2>/dev/null
    fi
done

echo ">>> แก้ไขเสร็จสมบูรณ์! (Fix Applied Successfully)" > /dev/tty1
echo ">>> ขอให้สนุกกับ PLAY OS ครับ!" > /dev/tty1
sleep 3
