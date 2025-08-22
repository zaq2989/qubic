#!/bin/bash
# SPDX-License-Identifier: MIT

# Start SSH
service ssh start

# Start MySQL (with weak config for PoC)
service mysql start
mysql -e "CREATE DATABASE IF NOT EXISTS testdb;"
mysql -e "CREATE USER IF NOT EXISTS 'testuser'@'%' IDENTIFIED BY 'password123';"
mysql -e "GRANT ALL ON testdb.* TO 'testuser'@'%';"
mysql -e "FLUSH PRIVILEGES;"

# Create vulnerable table
mysql testdb -e "CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY, username VARCHAR(50), password VARCHAR(50));"
mysql testdb -e "INSERT IGNORE INTO users VALUES (1, 'admin', 'admin123'), (2, 'user', 'user123');"

# Start Apache
service apache2 start

# Simple echo server on port 8080 (command injection target)
while true; do
    nc -l -p 8080 -c 'while read line; do echo "Echo: $line"; done'
done &

# Keep container running
tail -f /var/log/apache2/access.log