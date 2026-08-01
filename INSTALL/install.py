import os
import sys
import time
import threading
import subprocess
import zipfile
import ctypes
from ctypes import wintypes
import customtkinter as ctk
from tkinter import messagebox
from PIL import Image

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

# Win32 API Constants สำหรับการเขียนไฟล์ (Unbuffered Direct Write)
GENERIC_READ = 0x80000000
GENERIC_WRITE = 0x40000000
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
OPEN_EXISTING = 3
FILE_FLAG_NO_BUFFERING = 0x20000000  # ข้าม RAM Buffer เขียนตรงลงชิป
FILE_FLAG_WRITE_THROUGH = 0x80000000 # บังคับ Flush ข้อมูลลง Hardware ทันที
INVALID_HANDLE_VALUE = -1

def get_base_path():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    else:
        return os.path.dirname(os.path.abspath(__file__))

class PlayOSInstaller(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("PLAY OS Setup")
        self.geometry("380x380")
        self.resizable(False, False)
        
        self.selected_drive = ctk.StringVar(value="Select SD Card...")
        self.show_logs = ctk.BooleanVar(value=False)
        self.install_thread = None
        
        base_path = get_base_path()
        self.img_file = os.path.join(base_path, "pLay_OS.img")
        self.zip_file = os.path.join(base_path, "PLAYROM.zip")
        self.logo_path = os.path.join(base_path, "logo.png")
        self.dd_exe = os.path.join(base_path, "dd.exe")

        self.setup_ui()

    def setup_ui(self):
        self.container = ctk.CTkFrame(self, fg_color="transparent")
        self.container.place(relx=0.5, rely=0.5, anchor="center")

        self.create_main_screen()
        self.create_install_screen()
        self.create_success_screen()

        self.show_frame(self.main_frame)

    def show_frame(self, frame):
        for f in (self.main_frame, self.install_frame, self.success_frame):
            f.pack_forget()
        frame.pack(fill="both", expand=True)

    def create_main_screen(self):
        self.main_frame = ctk.CTkFrame(self.container, fg_color="transparent")
        
        if os.path.exists(self.logo_path):
            img = Image.open(self.logo_path)
            self.logo_img_main = ctk.CTkImage(light_image=img, dark_image=img, size=(130, 130))
            logo_lbl = ctk.CTkLabel(self.main_frame, text="", image=self.logo_img_main)
            logo_lbl.pack(pady=(0, 5))
        
        title_lbl = ctk.CTkLabel(self.main_frame, text="PLAY OS", font=ctk.CTkFont(family="Helvetica", size=22, weight="bold"))
        title_lbl.pack(pady=(0, 2))
        
        sub_lbl = ctk.CTkLabel(self.main_frame, text="Select drive and click Continue.", font=ctk.CTkFont(size=12), text_color="gray")
        sub_lbl.pack(pady=(0, 15))

        drive_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        drive_frame.pack(pady=5)

        self.drive_dropdown = ctk.CTkOptionMenu(
            drive_frame, 
            variable=self.selected_drive,
            values=self.get_removable_drives(),
            width=200,
            height=32,
            font=ctk.CTkFont(size=12)
        )
        self.drive_dropdown.pack(side="left", padx=(0, 5))

        refresh_btn = ctk.CTkButton(drive_frame, text="↻", width=32, height=32, font=ctk.CTkFont(size=14), command=self.refresh_drives)
        refresh_btn.pack(side="left")

        install_btn = ctk.CTkButton(
            self.main_frame, 
            text="Continue", 
            width=200, 
            height=35, 
            font=ctk.CTkFont(size=14, weight="bold"),
            command=self.start_installation
        )
        install_btn.pack(pady=(20, 0))

    def create_install_screen(self):
        self.install_frame = ctk.CTkFrame(self.container, fg_color="transparent")
        
        if os.path.exists(self.logo_path):
            img = Image.open(self.logo_path)
            self.logo_img_inst = ctk.CTkImage(light_image=img, dark_image=img, size=(80, 80))
            logo_lbl = ctk.CTkLabel(self.install_frame, text="", image=self.logo_img_inst)
            logo_lbl.pack(pady=(0, 5))

        self.status_label = ctk.CTkLabel(self.install_frame, text="Preparing...", font=ctk.CTkFont(size=14, weight="bold"))
        self.status_label.pack(pady=(0, 10))

        self.progress_bar = ctk.CTkProgressBar(self.install_frame, width=280, height=12)
        self.progress_bar.set(0)
        self.progress_bar.pack(pady=5)
        
        self.percent_label = ctk.CTkLabel(self.install_frame, text="0%", font=ctk.CTkFont(size=11), text_color="gray")
        self.percent_label.pack(pady=(0, 10))

        nerd_switch = ctk.CTkSwitch(self.install_frame, text="Show Logs", variable=self.show_logs, command=self.toggle_logs, font=ctk.CTkFont(size=11))
        nerd_switch.pack(pady=2)

        self.log_box = ctk.CTkTextbox(self.install_frame, width=320, height=100, font=ctk.CTkFont(family="Consolas", size=10))
        self.log_box.configure(state="disabled")

    def create_success_screen(self):
        self.success_frame = ctk.CTkFrame(self.container, fg_color="transparent")
        
        check_label = ctk.CTkLabel(self.success_frame, text="✔", font=ctk.CTkFont(size=70), text_color="#28a745")
        check_label.pack(pady=(20, 10))
        
        success_label = ctk.CTkLabel(self.success_frame, text="Installation Complete", font=ctk.CTkFont(size=20, weight="bold"))
        success_label.pack(pady=5)
        
        sub_success = ctk.CTkLabel(self.success_frame, text="You can now disconnect your SD card.", font=ctk.CTkFont(size=12), text_color="gray")
        sub_success.pack(pady=(0, 20))
        
        close_btn = ctk.CTkButton(self.success_frame, text="Finish", width=200, height=35, command=self.destroy)
        close_btn.pack(pady=10)

    def get_removable_drives(self):
        drives = []
        try:
            cmd = 'powershell "Get-CimInstance Win32_DiskDrive | Where-Object {$_.InterfaceType -eq \'USB\' -or $_.MediaType -like \'*Removable*\'} | Select-Object DeviceID, Model, Size"'
            proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=0x08000000)
            out, _ = proc.communicate()
            lines = out.decode('utf-8', errors='ignore').split('\n')
            for line in lines:
                if "PHYSICALDRIVE" in line:
                    parts = line.split()
                    device_id = parts[0]
                    try:
                        size_bytes = int(parts[-1])
                        size_gb = size_bytes / (1024**3)
                        model = " ".join(parts[1:-1])
                        drives.append(f"{device_id} - {model} ({size_gb:.1f} GB)")
                    except:
                        pass
        except Exception as e:
            pass
        if not drives: drives = ["No Removable Drives Found"]
        return drives

    def refresh_drives(self):
        drives = self.get_removable_drives()
        self.drive_dropdown.configure(values=drives)
        self.selected_drive.set(drives[0] if drives else "Select SD Card...")

    def toggle_logs(self):
        if self.show_logs.get():
            self.geometry("380x480")
            self.log_box.pack(pady=5, fill="x")
        else:
            self.geometry("380x380")
            self.log_box.pack_forget()

    def update_ui_safe(self, status_text, progress_val, log_text=None):
        self.status_label.configure(text=status_text)
        self.progress_bar.set(progress_val)
        self.percent_label.configure(text=f"{int(progress_val * 100)}%")
        
        if log_text:
            self.log_box.configure(state="normal")
            self.log_box.insert("end", f"[{time.strftime('%H:%M:%S')}] {log_text}\n")
            self.log_box.see("end")
            self.log_box.configure(state="disabled")

    def start_installation(self):
        selected = self.selected_drive.get()
        if "No Removable Drives Found" in selected or "Select" in selected:
            messagebox.showerror("Error", "Please select a valid SD Card!")
            return

        if not os.path.exists(self.dd_exe):
            messagebox.showerror("Error", "ไม่พบไฟล์: dd.exe\n")
            return
        if not os.path.exists(self.img_file):
            messagebox.showerror("Error", "ไม่พบไฟล์ระบบ: pLay_OS.img")
            return

        confirm = messagebox.askyesno("Warning", f"ข้อมูลทั้งหมดใน {selected} จะถูกลบอย่างถาวร ยืนยันหรือไม่?")
        if not confirm:
            return

        self.show_frame(self.install_frame)
        physical_drive = selected.split(" - ")[0] 

        self.install_thread = threading.Thread(target=self.installation_worker, args=(physical_drive,))
        self.install_thread.daemon = True
        self.install_thread.start()

    def installation_worker(self, physical_drive):
        disk_num = physical_drive.replace("\\\\.\\PHYSICALDRIVE", "").strip()
        script_path = os.path.join(os.environ['TEMP'], "disk_script.txt")

        try:
            import re
            
            self.after(0, self.update_ui_safe, "Preparing System...", 0.0, "[INIT] Disabling Windows AutoMount")
            subprocess.run(["mountvol", "/N"], capture_output=True, creationflags=0x08000000)

            self.after(0, self.update_ui_safe, "Cleaning SD Card...", 0.02, "[CLEAN] Destroying old OS partitions...")
            # คำสั่งล้างไพ่: ออฟไลน์ > ออนไลน์ > ปลด Readonly > Clean
            clean_cmd = f"select disk {disk_num}\noffline disk\nonline disk\nattributes disk clear readonly\nclean\nrescan\n"
            with open(script_path, "w") as f: f.write(clean_cmd)
            subprocess.run(["diskpart", "/s", script_path], capture_output=True, creationflags=0x08000000)
            self.after(0, self.update_ui_safe, "SD Card Cleaned", 0.05, "[CLEAN] SD Card is now 100% Unallocated.")
            time.sleep(1)

            self.after(0, self.update_ui_safe, "Flashing PLAY OS...", 0.05, "[FLASH] Starting dd.exe Engine (True Speed)...")
            
            total_size = os.path.getsize(self.img_file)
            dd_cmd = f'"{self.dd_exe}" if="{self.img_file}" of=\\\\.\\PhysicalDrive{disk_num} bs=4M --progress'
            
            # รัน dd.exe ซ่อนหน้าต่างดำ และจับตัวเลข Progress
            process = subprocess.Popen(dd_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, creationflags=0x08000000)

            while True:
                output = process.stdout.readline()
                if output == '' and process.poll() is not None:
                    break
                if output:
                    match = re.search(r'(\d+)\s+bytes', output)
                    if match:
                        written_bytes = int(match.group(1))
                        progress = 0.05 + (written_bytes / total_size) * 0.65
                        mb_written = written_bytes // (1024 * 1024)
                        mb_total = total_size // (1024 * 1024)
                        self.after(0, self.update_ui_safe, f"Flashing OS ({mb_written}/{mb_total} MB)", progress, f"[FLASH] Engine: {mb_written} MB written")

            if process.returncode != 0:
                raise Exception("dd.exe engine failed to flash the image.")

            self.after(0, self.update_ui_safe, "OS Flashed Successfully", 0.70, "[FLASH] OS Image successfully written.")
            
            self.after(0, self.update_ui_safe, "System Recovery...", 0.72, "[SYS] Re-enabling Windows AutoMount...")
            subprocess.run(["mountvol", "/E"], capture_output=True, creationflags=0x08000000)
            time.sleep(2)

            self.after(0, self.update_ui_safe, "Creating EASYROMS...", 0.75, "[PARTITION] Formatting exFAT...")
            part_cmd = f"select disk {disk_num}\nrescan\ncreate partition primary\nformat fs=exfat label=\"EASYROMS\" quick override\nassign\n"
            with open(script_path, "w") as f: f.write(part_cmd)
            subprocess.run(["diskpart", "/s", script_path], capture_output=True, creationflags=0x08000000)
            time.sleep(3)

            self.after(0, self.update_ui_safe, "Locating Drive...", 0.78, "[EXTRACT] Locating EASYROMS drive letter...")
            
            easyroms_path = None
            for letter in ['D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N']:
                if os.path.exists(f"{letter}:\\"):
                    try:
                        vol_name = ctypes.create_unicode_buffer(256)
                        ctypes.windll.kernel32.GetVolumeInformationW(ctypes.c_wchar_p(f"{letter}:\\"), vol_name, ctypes.sizeof(vol_name), None, None, None, None, 0)
                        if vol_name.value == "EASYROMS":
                            easyroms_path = f"{letter}:\\"
                            self.after(0, self.update_ui_safe, "Drive Found!", 0.80, f"[EXTRACT] Found EASYROMS at {easyroms_path}")
                            break
                    except: pass

            if easyroms_path and os.path.exists(self.zip_file):
                self.after(0, self.update_ui_safe, "Extracting ROMs...", 0.82, "[EXTRACT] Unzipping PLAYROM.zip (Real-time progress)...")
                
                with zipfile.ZipFile(self.zip_file, 'r') as zip_ref:
                    members = zip_ref.infolist()
                    total_files = len(members)
                    
                    for index, member in enumerate(members):
                        zip_ref.extract(member, easyroms_path)
                        zip_prog = 0.82 + ((index + 1) / total_files) * 0.18
                        
                        if index % 5 == 0 or index == total_files - 1:
                            filename = os.path.basename(member.filename)
                            if filename:
                                self.after(0, self.update_ui_safe, f"Extracting... ({int(zip_prog*100)}%)", zip_prog, f" > Unzipped: {filename}")

            if os.path.exists(script_path): os.remove(script_path)

            self.after(0, self.update_ui_safe, "Completed!", 1.0, "[SUCCESS] Setup complete!")
            time.sleep(1)
            self.after(0, self.show_frame, self.success_frame)

        except Exception as e:
            self.after(0, self.update_ui_safe, "Error Occurred!", 0.0, f"[ERROR] {str(e)}")
            messagebox.showerror("Error", f"Installation Failed:\n{str(e)}")
        finally:
            subprocess.run(["mountvol", "/E"], capture_output=True, creationflags=0x08000000)
            if os.path.exists(script_path): os.remove(script_path)

if __name__ == "__main__":
    try:
        is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        is_admin = False

    if not is_admin:
        ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)
        sys.exit()

    app = PlayOSInstaller()
    app.mainloop()