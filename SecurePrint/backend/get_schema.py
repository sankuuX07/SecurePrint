import sqlite3
conn = sqlite3.connect('secureprint.db')
c = conn.cursor()
c.execute("PRAGMA table_info(documents)")
print("Columns in documents:")
for row in c.fetchall():
    print(row)
