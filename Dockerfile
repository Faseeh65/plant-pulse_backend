FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements from ROOT
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- CACHE BUSTING FOR MODELS ---
ARG CACHEBUST=1
RUN echo "Syncing Rice-Fusion Model from ROOT... Revision: $CACHEBUST"

# Copy all source files from ROOT into /app
COPY . .

# Verify the copy in logs (checking root dir)
RUN ls -R .

# Start the server (directly from root)
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
