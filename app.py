import os

import uvicorn

from main import app as fastapi_app


# Vercel looks for a FastAPI instance named `app` in app.py.
app = fastapi_app


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port, reload=False)
