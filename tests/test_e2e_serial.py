import pexpect
import sys
import time

def main():
    print("Starting QEMU...")
    # Remove old QEMU pid just in case
    child = pexpect.spawn(
        'qemu-kvm',
        [
            '-m', '4G',
            '-smp', '4',
            '-drive', 'file=/etc/kryonix/result/iso/kryonix.iso,format=raw,readonly=on,media=cdrom',
            '-drive', 'file=/tmp/kryonix_e2e_disk.qcow2,format=qcow2,if=virtio',
            '-device', 'virtio-gpu-pci',
            '-device', 'virtio-net-pci,netdev=net0',
            '-netdev', 'user,id=net0',
            '-display', 'none',
            '-serial', 'stdio'
        ],
        encoding='utf-8',
        timeout=180
    )
    child.logfile = sys.stdout

    try:
        # Wait for the login prompt on serial console
        child.expect('kryonix login: ')
        child.sendline('root')

        # Wait for the shell prompt
        child.expect('root@kryonix:~#')
        
        # Give the backend a few seconds to start
        time.sleep(10)

        # 1. Test /health
        print("\n--- Testing /health ---")
        child.sendline('curl -s http://127.0.0.1:8080/health')
        child.expect('root@kryonix:~#')
        print(child.before)

        # 2. Test /api/disks
        print("\n--- Testing /api/disks ---")
        child.sendline('curl -s http://127.0.0.1:8080/api/disks')
        child.expect('root@kryonix:~#')
        print(child.before)

        # 3. Test /hardware
        print("\n--- Testing /hardware ---")
        child.sendline('curl -s http://127.0.0.1:8080/hardware')
        child.expect('root@kryonix:~#')
        print(child.before)

        # 4. Check KRYONIX_ENGINE_SOURCE
        print("\n--- Testing Engine Source ---")
        child.sendline('cat /etc/systemd/system/kryonix-installer-backend.service | grep KRYONIX_ENGINE_SOURCE')
        child.expect('root@kryonix:~#')
        print(child.before)

        print("\nAll preflight serial tests completed.")
        
    except pexpect.TIMEOUT:
        print("Timeout occurred!")
    except pexpect.EOF:
        print("EOF occurred!")
    finally:
        child.close()

if __name__ == '__main__':
    main()
