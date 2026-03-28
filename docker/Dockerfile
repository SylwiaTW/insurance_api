FROM python:3.12-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .
COPY dataset/ ./dataset/

RUN useradd --no-create-home appuser
USER appuser

EXPOSE 80

CMD ["python", "main.py"]
