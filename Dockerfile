
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements from backend folder
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- CACHE BUSTING FOR MODELS ---
ARG CACHEBUST=1
RUN echo "Syncing Rice-Fusion Model from backend/ folder... Revision: $CACHEBUST"

# Copy the backend folder as a subfolder to preserve namespacing
COPY backend/ ./backend/

# Verify the copy in logs
RUN ls -R /app/backend/AI_Model/

# Expose port and start
# Note: we use sh -c to expand the $PORT environment variable provided by Railway
CMD ["sh", "-c", "uvicorn backend.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
