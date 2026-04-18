import sys

def fix_file(filename, line_docs):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    line_docs.sort(key=lambda x: x[0], reverse=True)
    
    for line_num, func_name in line_docs:
        idx = line_num - 1
        if idx >= 0 and idx < len(lines):
            search_idx = idx - 1
            while search_idx >= 0 and lines[search_idx].strip() == "":
                search_idx -= 1
            
            if search_idx >= 0 and lines[search_idx].strip().startswith("///"):
                continue
            
            indent = ""
            current_line = lines[idx]
            for char in current_line:
                if char.isspace():
                    indent += char
                else:
                    break
            
            lines.insert(idx, f"{indent}/// Handles `{func_name}`.\n")
            
    with open(filename, 'w') as f:
        f.writelines(lines)

files_to_fix = {}
try:
    with open("/tmp/to_fix.txt", "r") as f:
        for line in f:
            parts = line.strip().split(":")
            if len(parts) == 3:
                file, lnum, fname = parts
                if file not in files_to_fix:
                    files_to_fix[file] = []
                files_to_fix[file].append((int(lnum), fname))

    for filename, docs in files_to_fix.items():
        fix_file(filename, docs)
except Exception as e:
    print(f"Error: {e}")
