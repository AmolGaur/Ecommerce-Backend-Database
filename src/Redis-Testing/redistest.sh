#!/bin/bash

# Variables
DB_NAME="ecommerce"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_HOST="localhost"
DB_PORT="5432"
CACHE_KEY="user_query_cache"
TTL=3600  # Time-to-live in seconds (1 hour)

# Set the PGPASSWORD environment variable to avoid password prompts
export PGPASSWORD=$DB_PASSWORD

# Prompt the user to input a query
echo "Please enter the SQL query you would like to run:"
read -r QUERY  # Read the user's input as the query

# Generate a cache key based on the query to avoid duplicate caching
CACHE_KEY="query_cache:$(echo -n "$QUERY" | md5sum | awk '{print $1}')"

# Check if the result is in Redis cache
START_TIME=$(date +%s%3N)  # Start time in milliseconds
RESULT=$(redis-cli GET "$CACHE_KEY")

if [ -z "$RESULT" ]; then
    # Cache miss: query PostgreSQL and cache the result in Redis
    echo "Cache miss. Querying PostgreSQL..."
    RESULT=$(psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" -c "$QUERY" -t -A)

    # Store the result in Redis
    redis-cli SET "$CACHE_KEY" "$RESULT"
    redis-cli EXPIRE "$CACHE_KEY" "$TTL"
    echo "Data cached in Redis."
else
    echo "Cache hit. Data fetched from Redis."
fi

END_TIME=$(date +%s%3N)  # End time in milliseconds

# Calculate the time taken
TIME_TAKEN=$((END_TIME - START_TIME))
echo "Time taken: ${TIME_TAKEN} milliseconds"

# Display the result
echo "$RESULT"

# Unset the password variable for security
unset PGPASSWORD

