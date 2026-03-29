FROM python:3.12-slim AS builder

WORKDIR /app

COPY app/requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


FROM python:3.12-slim

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY app/ .

ENV PATH="/opt/venv/bin:$PATH"

RUN useradd --no-create-home appuser
USER appuser

EXPOSE 80

CMD ["python", "main.py"]
