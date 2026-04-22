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

# Copy the backend folder contents to /app
COPY backend/ .

# Verify the copy in logs
RUN ls -R /app/AI_Model/

# Expose port and start
# Note: we are now in /app where main.py was copied from backend/
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
