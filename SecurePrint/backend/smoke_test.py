import time
import subprocess
from pywinauto.application import Application
from pywinauto.keyboard import send_keys

exe_path = r"C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe"

print("Launching EXE via pywinauto...")
app = Application(backend="uia").start(exe_path)

print("Waiting for startup...")
time.sleep(8)

try:
    dlg = app.window(title_re=".*SecurePrint.*")
    dlg.wait('visible', timeout=10)
    print("Window found! Sending keys...")
    
    # Just to ensure it's in focus
    dlg.set_focus()
    time.sleep(1)
    
    send_keys("sbbe29104@t.com")
    time.sleep(0.5)
    send_keys("{TAB}")
    time.sleep(0.5)
    send_keys("ShopPass123!")
    time.sleep(0.5)
    send_keys("{ENTER}")
    
    print("Sent login credentials, waiting...")
    time.sleep(5)
    
    print("Interaction complete. Check backend logs for success.")
except Exception as e:
    print(f"Error: {e}")
finally:
    print("Killing app...")
    app.kill()
