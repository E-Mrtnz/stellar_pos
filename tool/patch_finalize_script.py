from pathlib import Path

p = Path(__file__).with_name('finalize_sales_operation_flow.py')
s = p.read_text()
s = s.replace("if '_startReturnOperation' not in text:", "if 'void _startReturnOperation' not in text:")
old = '''    text2, count = re.subn(r"\\s*if \\(replacement\\.stock < quantity\\) throw StateError\\('No hay suficiente existencia del producto nuevo para realizar el cambio\\.\\'\\);", '', text, count=1)'''
new = '''    guard = "if (replacement.stock < quantity) throw StateError('No hay suficiente existencia del producto nuevo para realizar el cambio.');"\n    text2 = text.replace(guard, '', 1)\n    count = 1 if text2 != text else 0'''
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s)
print('Patched finalize script.')
