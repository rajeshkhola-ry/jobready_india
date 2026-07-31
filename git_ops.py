import subprocess, sys
repo = r'C:\JobReadyIndia\jobready_india'
cmds = [
    ['git', '-C', repo, 'add', '.'],
    ['git', '-C', repo, 'commit', '-m', 'Deploy latest workspace, homepage upload, HD Photo studio, T&C, and Cookie Banner updates'],
    ['git', '-C', repo, 'push', 'origin', 'main'],
]
for cmd in cmds:
    print('> ' + ' '.join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    print('exit', result.returncode)
    if result.returncode != 0:
        sys.exit(result.returncode)
