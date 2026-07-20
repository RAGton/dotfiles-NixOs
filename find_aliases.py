import os
import re

def find_compat_aliases(directory):
    found = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.nix'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r') as f:
                        content = f.read()
                    
                    # Remove block comments /* ... */
                    content_stripped = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                    # Remove line comments
                    content_stripped = re.sub(r'#.*', '', content_stripped)
                    # Remove all whitespace
                    content_stripped = re.sub(r'\s+', '', content_stripped)
                    
                    # Pattern for a single import that goes UP a directory
                    # e.g. {imports=[../common];}
                    pattern = r'^(\{[\w,\.\-]*\}:)?\{imports=\[\.\./[^\]]+\];?\}$'
                    
                    if re.match(pattern, content_stripped):
                        found.append(filepath)
                except Exception as e:
                    pass
    
    for p in found:
        print(f"COMPAT_ALIAS: {p}")

if __name__ == '__main__':
    print("Scanning for compat aliases...")
    find_compat_aliases('.')
