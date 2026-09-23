from fastapi import FastAPI

app = FastAPI(title='GhostStream API', version='2.0')


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'ghoststream-api'}
