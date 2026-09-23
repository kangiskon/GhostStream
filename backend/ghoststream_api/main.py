from fastapi import FastAPI
from .routes.auth import router as auth_router
from .routes.devices import router as devices_router
from .routes.sync import activity_router, diagnostics_router, router as sync_router, sources_router

app = FastAPI(title='GhostStream API', version='2.0')
app.include_router(auth_router)
app.include_router(devices_router)
app.include_router(sync_router)
app.include_router(sources_router)
app.include_router(diagnostics_router)
app.include_router(activity_router)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'ghoststream-api'}
