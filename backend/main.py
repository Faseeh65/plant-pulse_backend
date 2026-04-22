from inference_server import app, CLASS_NAMES

# FALLBACK WRAPPER
# This file exists to prevent 404/500 errors if Railway is hardcoded to look for 'main:app'.
# Everything is handled in 'inference_server.py'.

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
