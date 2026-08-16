FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN pip install --no-cache-dir "Flask>=3.0,<4" "requests>=2.31,<3" "gunicorn>=22,<24"

COPY main.py /app/main.py

CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT:-10000} main:app"]
