ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null kryonix@192.168.122.113 "nmcli -t -f NAME,TYPE,DEVICE,IP4.ADDRESS connection show --active"
