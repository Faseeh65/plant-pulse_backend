FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
# We do this at /app level to cache dependencies separately from code
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- STEP INTO BACKEND ---
# Setting the working directory to the backend folder as requested
WORKDIR /app/backend

# --- CACHE BUSTING FOR MODELS ---
ARG CACHEBUST=1
RUN echo "Syncing Rice-Fusion Model... Revision: $CACHEBUST"

# Copy the backend folder contents directly into the current WORKDIR (/app/backend)
COPY backend/ .

# Verify the copy in logs (checking current dir)
RUN ls -R .

# Expose port and start
# Since we are already in /app/backend, we run 'main:app' directly
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
