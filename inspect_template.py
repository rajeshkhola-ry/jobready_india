import zipfile
import os
path = os.path.join('assets', 'template.docx')
print('exists:', os.path.exists(path))
with zipfile.ZipFile(path, 'r') as z:
    print('files:', [name for name in z.namelist() if name.startswith('word/')][:20])
    if 'word/document.xml' in z.namelist():
        data = z.read('word/document.xml').decode('utf-8', errors='replace')
        for i, line in enumerate(data.splitlines()[:120], 1):
            print(f'{i:03}: {line}')
    else:
        print('missing document.xml')
