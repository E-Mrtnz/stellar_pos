from pathlib import Path
p = Path(__file__).with_name('finalize_sales_operation_flow.py')
s = p.read_text()
s = s.replace("if '_startReturnOperation' not in text:", "if 'void _startReturnOperation' not in text:")
p.write_text(s)
print('Patched finalize script condition.')
