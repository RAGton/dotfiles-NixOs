tmp_log=$(mktemp)
echo "Existing file '/home/rocha/.config/mimeapps.list.backup' would be clobbered by backing up '/home/rocha/.config/mimeapps.list'" > "$tmp_log"
if grep -q "would be clobbered by backing up" "$tmp_log"; then
  backup_file=$(grep "would be clobbered by backing up" "$tmp_log" | sed -n "s/.*Existing file '\(.*\.backup\)' would be clobbered.*/\1/p")
  echo "Found backup file: $backup_file"
fi
