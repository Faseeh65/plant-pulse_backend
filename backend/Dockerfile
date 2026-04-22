FROM python:3.10-slim

WORKDIR /app

# Updated system dependencies for newer Debian versions
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy local files (everything in /backend) into /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Check if main.py exists during build
RUN ls -la


# We use the shell form without brackets to ensure Railway's $PORT is injected correctly
CMD uvicorn main:app --host 0.0.0.0 --port $PORT