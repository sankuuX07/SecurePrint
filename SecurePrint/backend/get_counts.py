import sqlite3

conn = sqlite3.connect('secureprint.db')
c = conn.cursor()
tables = ['users', 'shops', 'shop_pricing', 'documents', 'print_jobs']
for t in tables:
    try:
        c.execute(f"SELECT COUNT(*) FROM {t}")
        print(f"{t}: {c.fetchone()[0]}")
    except Exception as e:
        print(f"{t}: Error {e}")
