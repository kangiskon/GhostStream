from fastapi import FastAPI
from .routes.auth import router as auth_router

app = FastAPI(title='GhostStream API', version='2.0')
app.include_router(auth_router)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'ghoststream-api'}
