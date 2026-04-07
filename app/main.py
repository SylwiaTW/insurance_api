import io
import os
import pandas as pd
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from flask import Flask, jsonify, abort

app = Flask(__name__)

STORAGE_ACCOUNT_URL = os.environ.get("STORAGE_ACCOUNT_URL")
CONTAINER_NAME = os.environ.get("BLOB_CONTAINER", "dataset")
BLOB_NAME = os.environ.get("BLOB_NAME", "dataset.csv")

try:
    credential = DefaultAzureCredential()
    client = BlobServiceClient(
        account_url=STORAGE_ACCOUNT_URL,
        credential=credential,
    )
    blob = client.get_blob_client(container=CONTAINER_NAME, blob=BLOB_NAME)
    data = blob.download_blob().readall()
    _df = pd.read_csv(io.BytesIO(data))
except Exception as e:
    print(f"Failed to load dataset: {e}", flush=True)
    _df = pd.DataFrame()


@app.get("/health")
def health():
    return f"ok, loaded {len(_df)} records"


@app.get("/insurance-data")
def get_data():
    if _df.empty:
        abort(503, description="Dataset not available")

    last_data = _df.tail(10)
    return jsonify(last_data.to_dict(orient="records"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
