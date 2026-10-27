FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /srv
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app ./app
COPY static ./static
# Cloud Run provides $PORT
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}
