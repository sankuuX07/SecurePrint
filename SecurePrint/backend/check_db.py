import sqlite3
conn = sqlite3.connect('secureprint.db')
cur = conn.cursor()
cur.execute("SELECT email, role, status FROM users")
for row in cur.fetchall():
    print(row)
conn.close()
