{
  lib,
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  util-linux,
  pciutils,
  jq,
}:

writeShellApplication {
  name = "kryonix-hardware-probe";

  runtimeInputs = [
    coreutils
    gawk
    gnugrep
    util-linux
    pciutils
    jq
  ];

  text = ''
    # Board UUID — readable from sysfs without root on most hardware
    board_uuid="unknown"
    if [[ -r /sys/class/dmi/id/product_uuid ]]; then
      board_uuid=$(tr -d '[:space:]' < /sys/class/dmi/id/product_uuid)
    fi

    # CPU — force C locale so field names are predictable regardless of system locale
    cpu_vendor=$(LANG=C lscpu | awk -F': +' '/^Vendor ID:/{print $2; exit}')
    cpu_model=$(LANG=C lscpu | awk -F': +' '/^Model name:/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}')
    cpu_cores=$(LANG=C lscpu | awk -F': +' '/^CPU\(s\):/{print $2 + 0; exit}')
    case "$cpu_vendor" in
      GenuineIntel) cpu_vendor="Intel" ;;
      AuthenticAMD) cpu_vendor="AMD" ;;
    esac

    # GPUs — lspci -nn appends [vendorid:deviceid] at end of each line
    gpu_lines=$(lspci -nn | grep -E "(VGA compatible controller|3D controller|Display controller)" || true)
    gpu_json="[]"
    if [[ -n "$gpu_lines" ]]; then
      gpu_json=$(printf '%s\n' "$gpu_lines" | while IFS= read -r line; do
        slot=$(printf '%s' "$line" | cut -d' ' -f1)
        # lspci -nn appends (rev XX) after [vendor:device], so match last [xxxx:xxxx]
        pci_id=$(printf '%s' "$line" | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' | tail -1 | tr -d '[]' || true)
        vmm=$(lspci -vmm -s "$slot" 2>/dev/null || true)
        vendor=$(printf '%s' "$vmm" | awk -F':\t' '/^Vendor/{print $2; exit}')
        model=$(printf '%s' "$vmm" | awk -F':\t' '/^Device/{print $2; exit}')
        jq -n \
          --arg vendor "$vendor" \
          --arg model  "$model" \
          --arg pci_id "$pci_id" \
          '{"vendor":$vendor,"model":$model,"pci_id":$pci_id}'
      done | jq -s '.')
    fi

    # Disks — lsblk -b returns SIZE as integer bytes, ROTA as boolean in JSON
    disks_json=$(lsblk -d -b -o NAME,SIZE,TYPE,ROTA --json 2>/dev/null | jq '[
      .blockdevices[]
      | select(.type == "disk")
      | {
          path: ("/dev/" + .name),
          size_gb: (.size / 1073741824 | floor),
          type: (
            if   (.name | startswith("nvme"))  then "nvme"
            elif (.rota == false or .rota == 0 or .rota == "0") then "ssd"
            else "hdd"
            end
          )
        }
    ]')

    # Memory (integer GB)
    mem_kb=$(awk '/^MemTotal/{print $2}' /proc/meminfo)
    mem_gb=$(( mem_kb / 1024 / 1024 ))

    jq -n \
      --arg  board_uuid  "$board_uuid" \
      --arg  cpu_vendor  "$cpu_vendor" \
      --arg  cpu_model   "$cpu_model" \
      --argjson cpu_cores  "$cpu_cores" \
      --argjson gpus       "$gpu_json" \
      --argjson memory_gb  "$mem_gb" \
      --argjson disks      "$disks_json" \
      '{
        board_uuid: $board_uuid,
        cpu:        {vendor: $cpu_vendor, model: $cpu_model, cores: $cpu_cores},
        gpu:        $gpus,
        memory_gb:  $memory_gb,
        disks:      $disks
      }'
  '';

  meta = with lib; {
    description = "Kryonix hardware detection tool — emits JSON to stdout";
    homepage = "https://github.com/RAGton/kryonix";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
