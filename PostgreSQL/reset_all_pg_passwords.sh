reset_all_pg_passwords.sh
#!/bin/bash

# --- Ubuntu-Safe PostgreSQL Snap Password Reset ---
# Specifically formatted to avoid 'redirection unexpected' errors.

NEW_PASSWORD="postgres"

echo "------------------------------------------------"
echo "Starting Password Reset for PostgreSQL (Snap)..."
echo "------------------------------------------------"

# 1. Check if the Snap command exists
# if ! command -v /snap/bin/postgresql.psql &> /dev/null; then
#     echo "[ERROR] postgresql.psql not found. Is the Snap installed?"
#     exit 1
# fi

# 2. Get users and loop through them using a standard 'while' loop
# This avoids the 'mapfile' and 'redirection' issues you encountered
sudo /snap/bin/postgresql.psql -U postgres -t -c "SELECT rolname FROM pg_roles WHERE rolcanlogin = true;" | while read -r USERNAME; do
    # Clean up the username (remove whitespace)
    CLEAN_USER=$(echo "$USERNAME" | xargs)
    
    if [ -n "$CLEAN_USER" ]; then
        echo "Resetting password for: $CLEAN_USER"
        sudo /snap/bin/postgresql.psql -U postgres -c "ALTER ROLE \"$CLEAN_USER\" WITH PASSWORD '$NEW_PASSWORD';"
    fi
done

echo "------------------------------------------------"
echo "Process Complete."
echo "------------------------------------------------"