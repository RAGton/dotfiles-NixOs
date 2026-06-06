import os
import sys
import time
import json
import socket
import subprocess

QGA_SOCK = "/tmp/qga.sock"

def send_qga_command(cmd, wait_for_response=True):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.connect(QGA_SOCK)
            s.sendall((json.dumps(cmd) + "\n").encode('utf-8'))
            if wait_for_response:
                data = b""
                # Read until newline
                while b"\n" not in data:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    data += chunk
                return json.loads(data.decode('utf-8'))
    except Exception as e:
        print(f"QGA connection failed: {e}")
        return None

def guest_exec(cmd_path, args):
    req = {
        "execute": "guest-exec",
        "arguments": {
            "path": cmd_path,
            "arg": args,
            "capture-output": True
        }
    }
    res = send_qga_command(req)
    if not res or "return" not in res:
        # If guest-exec fails (e.g. command not found), it returns an error dict.
        return -1, "", str(res)
    
    pid = res["return"]["pid"]

    # Poll for completion
    while True:
        status_req = {
            "execute": "guest-exec-status",
            "arguments": {"pid": pid}
        }
        status_res = send_qga_command(status_req)
        if status_res and "return" in status_res and status_res["return"].get("exited", False):
            import base64
            out_b64 = status_res["return"].get("out-data", "")
            err_b64 = status_res["return"].get("err-data", "")
            out = base64.b64decode(out_b64).decode('utf-8') if out_b64 else ""
            err = base64.b64decode(err_b64).decode('utf-8') if err_b64 else ""
            return status_res["return"]["exitcode"], out, err
        time.sleep(1)

def main():
    print("Starting QEMU with guest agent...")
    
    if os.path.exists(QGA_SOCK):
        os.remove(QGA_SOCK)
        
    qemu_cmd = [
        "qemu-kvm",
        "-m", "4G",
        "-smp", "4",
        "-drive", "file=/tmp/kryonix-installer-final-iso/iso/kryonix.iso,format=raw,readonly=on,media=cdrom",
        "-drive", "file=/tmp/kryonix_e2e_disk.qcow2,format=qcow2,if=virtio",
        "-device", "virtio-gpu-pci",
        "-chardev", f"socket,path={QGA_SOCK},server=on,wait=off,id=qga0",
        "-device", "virtio-serial",
        "-device", "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0",
        "-display", "none"
    ]
    
    proc = subprocess.Popen(qemu_cmd)
    
    try:
        print("Waiting for QEMU guest agent socket...")
        while not os.path.exists(QGA_SOCK):
            time.sleep(1)
            
        print("Waiting for guest agent to respond (booting)...")
        ping_req = {"execute": "guest-ping"}
        max_wait = 120
        for _ in range(max_wait):
            res = send_qga_command(ping_req)
            if res and "return" in res:
                print("Guest agent is ALIVE!")
                break
            time.sleep(1)
        else:
            print("Timeout waiting for guest agent.")
            return
            
        print("Checking if backend is up...")
        for _ in range(90):
            code, out, err = guest_exec("/run/current-system/sw/bin/curl", ["-s", "http://127.0.0.1:8080/health"])
            if code == 0:
                print(f"Backend is UP! Health: {out}")
                break
            time.sleep(2)
        else:
            print("Timeout waiting for backend.")
            
        print("\n--- Running Preflight Commands ---")
        code, out, err = guest_exec("/run/current-system/sw/bin/ip", ["a"])
        print(f"IP: \n{out}")

        code, out, err = guest_exec("/run/current-system/sw/bin/lsblk", [])
        print(f"LSBLK: \n{out}")

        print("\n--- Testing /api/disks ---")
        code, out, err = guest_exec("/run/current-system/sw/bin/curl", ["-s", "http://127.0.0.1:8080/api/disks"])
        print(f"Code: {code}\nOutput: {out}\nError: {err}")

        print("\n--- Checking KRYONIX_ENGINE_SOURCE ---")
        code, out, err = guest_exec("/run/current-system/sw/bin/bash", ["-c", "cat /etc/systemd/system/kryonix-installer-backend.service | grep KRYONIX_ENGINE_SOURCE"])
        print(f"Code: {code}\nOutput: {out}\nError: {err}")
        
        print("\n--- Testing dry-run /dev/null ---")
        payload = json.dumps({
            "version": 1,
            "hostname": "kryonix-test",
            "timezone": "UTC",
            "locale": "en_US.UTF-8",
            "keyboard": "us",
            "disk": {
                "mode": "automatic",
                "target": "/dev/null",
                "layout": "btrfs",
                "boot_mode": "uefi",
                "profile": "desktop"
            },
            "user": {
                "name": "rocha",
                "password": "123",
                "admin": True,
                "authorized_keys": []
            },
            "features": {}
        })
        code, out, err = guest_exec("/run/current-system/sw/bin/curl", ["-s", "-X", "POST", "-H", "Content-Type: application/json", "-d", payload, "http://127.0.0.1:8080/dry-run"])
        print(f"Code: {code}\nOutput: {out}\nError: {err}")

        print("\n--- Testing dry-run /dev/vda ---")
        payload_vda = json.dumps({
            "version": 1,
            "hostname": "kryonix-test",
            "timezone": "UTC",
            "locale": "en_US.UTF-8",
            "keyboard": "us",
            "disk": {
                "mode": "automatic",
                "target": "/dev/vda",
                "layout": "btrfs",
                "boot_mode": "uefi",
                "profile": "desktop"
            },
            "user": {
                "name": "rocha",
                "password": "123",
                "admin": True,
                "authorized_keys": []
            },
            "features": {}
        })
        code, out, err = guest_exec("/run/current-system/sw/bin/curl", ["-s", "-X", "POST", "-H", "Content-Type: application/json", "-d", payload_vda, "http://127.0.0.1:8080/dry-run"])
        print(f"Code: {code}\nOutput: {out}\nError: {err}")
        
    finally:
        print("\nTests finished. Shutting down VM...")
        send_qga_command({"execute": "guest-shutdown"}, wait_for_response=False)
        proc.wait()
        print("VM shutdown complete.")

if __name__ == '__main__':
    main()
