FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- STEP INTO BACKEND ---
WORKDIR /app/backend

# --- CACHE BUSTING ---
ARG CACHEBUST=1
RUN echo "Syncing Logic to Backend Folder... Revision: $CACHEBUST"

# Copy the backend folder contents into the current WORKDIR (/app/backend)
COPY backend/ .

# Verify location
RUN ls -R .

# Start the server (directly from /app/backend)
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
