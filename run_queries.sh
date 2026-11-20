
#!/usr/bin/env bash
set -euo pipefail

# Move to the directory containing this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Locate SQLite.
if [[ -f "./sqlite3.exe" ]]; then
    SQLITE3="./sqlite3.exe"
elif [[ -f "./sqlite3" ]]; then
    SQLITE3="./sqlite3"
else
    echo "Error: sqlite3 executable not found in this directory."
    exit 1
fi

# Required SQL files.
for file in schema.sql insert_data.sql queries.sql transaction.sql; do
    if [[ ! -f "$file" ]]; then
        echo "Error: required file not found: $file"
        exit 1
    fi
done

# Recreate the database.
echo "Recreating database..."
rm -f ./online_bookstore.db

echo "Creating schema..."
"$SQLITE3" -bail ./online_bookstore.db < schema.sql

echo "Loading sample data..."
"$SQLITE3" -bail ./online_bookstore.db < insert_data.sql

echo
echo "Running queries..."
"$SQLITE3" -header -column -bail ./online_bookstore.db < queries.sql

echo
echo "Running transaction..."
"$SQLITE3" -bail ./online_bookstore.db < transaction.sql
