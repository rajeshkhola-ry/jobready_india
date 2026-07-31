from pathlib import Path
root = Path('C:/JobReadyIndia/jobready_india/build/web')
files = []
total = 0
for p in root.rglob('*'):
    if p.is_file():
        size = p.stat().st_size
        total += size
        files.append((p.relative_to(root).as_posix(), size))
files = sorted(files, key=lambda x: x[1], reverse=True)
print('TOTAL_BYTES', total)
print('TOTAL_MB', round(total / (1024 * 1024), 2))
print('TOP_FILES')
for rel, size in files[:30]:
    print(rel, size, round(size / (1024 * 1024), 2))
