from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette import status
import os
from pathlib import Path

app = FastAPI()

# Serve static
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates directory
templates = Jinja2Templates(directory="static/templates")

UPLOAD_DIR = Path("static/uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

MAX_BYTES = 5 * 1024 * 1024  # 5MB


@app.get("/", response_class=HTMLResponse)
async def serve_index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


@app.post("/upload")
async def upload(file: UploadFile = File(...)):
    content = await file.read()
    size = len(content)

    if size > MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds 5 MB limit ({size / 1024 / 1024:.2f} MB).",
        )

    if not file.filename:
        raise HTTPException(status_code=400, detail="Uploaded file has no filename")

    safe_name = os.path.basename(file.filename)
    dest = UPLOAD_DIR / safe_name
    with open(dest, "wb") as f:
        f.write(content)

    return JSONResponse(
        {
            "filename": safe_name,
            "size_bytes": size,
            "size_mb": f"{size / 1024 / 1024:.2f}",
            "content_type": file.content_type,
        }
    )
