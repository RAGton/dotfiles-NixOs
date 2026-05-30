#!/usr/bin/env bash
VM=kryonix-installer-test
VNC_PORT=5910

case "${1:-vnc}" in
  vnc)    vncviewer 127.0.0.1:$VNC_PORT ;;
  serial) sudo virsh console $VM ;;
  start)  sudo virsh start $VM ;;
  stop)   sudo virsh destroy $VM ;;
  status) sudo virsh dominfo $VM; sudo virsh domblklist $VM ;;
  logs)   sudo virsh console $VM --force ;;
  *)
    echo "Uso: $0 [vnc|serial|start|stop|status|logs]"
    exit 1
    ;;
esac
