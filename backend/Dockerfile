FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY pyproject.toml ./
COPY ghoststream_api ./ghoststream_api
RUN pip install --no-cache-dir .
RUN useradd --create-home --uid 10001 ghoststream
USER ghoststream
EXPOSE 8098
CMD ["uvicorn", "ghoststream_api.main:app", "--host", "0.0.0.0", "--port", "8098", "--proxy-headers"]
