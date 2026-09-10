from pathlib import Path

p = Path(__file__).with_name('finalize_sales_operation_flow.py')
s = p.read_text()
s = s.replace("if '_startReturnOperation' not in text:", "if 'void _startReturnOperation' not in text:")
lines = s.splitlines()
for i, line in enumerate(lines):
    if 'text2, count = re.subn' in line and 'replacement\\.stock' in line:
        lines[i:i + 1] = [
            '    guard = "if (replacement.stock < quantity) throw StateError(\'No hay suficiente existencia del producto nuevo para realizar el cambio.\');"',
            "    text2 = text.replace(guard, '', 1)",
            '    count = 1 if text2 != text else 0',
        ]
        break
else:
    raise SystemExit('Could not find stock guard regex in finalizer.')
p.write_text('\n'.join(lines) + '\n')
print('Patched finalize script.')
