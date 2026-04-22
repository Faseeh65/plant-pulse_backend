FROM python:3.10-slim

# 1. Set the working directory inside the container
WORKDIR /app

# 2. Install system dependencies for OpenCV and image processing
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 3. Copy requirements and install (Railway is already looking at /backend)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy all files from your local /backend folder into the container /app
COPY . .

# 5. Diagnostic: List files during build to verify main.py and AI_Model are there
RUN ls -R .

# 6. Start the server
# We use 'main:app' because main.py is in the same folder as this Dockerfile
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]