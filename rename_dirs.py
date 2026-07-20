import os

def rename_ragos_dirs(root_path):
    # Walk bottom-up so renaming a parent doesn't break paths to its children
    for dirpath, dirnames, filenames in os.walk(root_path, topdown=False):
        if '.git' in dirpath:
            continue
        for dirname in dirnames:
            if 'ragos' in dirname.lower():
                old_path = os.path.join(dirpath, dirname)
                # Just string replace ragos with node
                new_dirname = dirname.replace('ragos', 'node').replace('Ragos', 'Node').replace('RAGOS', 'NODE')
                new_path = os.path.join(dirpath, new_dirname)
                os.rename(old_path, new_path)
                print(f"Renamed {old_path} -> {new_path}")

if __name__ == '__main__':
    rename_ragos_dirs('.')
