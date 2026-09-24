import sqlite3
from app.core.security import get_password_hash

conn = sqlite3.connect('secureprint.db')
cur = conn.cursor()

pwd_hash = get_password_hash("ShopPass123!")
cur.execute("UPDATE users SET password_hash = ? WHERE email = 'sbbe29104@t.com'", (pwd_hash,))
conn.commit()
conn.close()
print("Updated shop password to ShopPass123!")
