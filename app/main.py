import io
import os
import pandas as pd
from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient
from flask import Flask, jsonify, request, abort

app = Flask(__name__)

STORAGE_ACCOUNT_URL = os.environ.get("STORAGE_ACCOUNT_URL")
CONTAINER_NAME = os.environ.get("BLOB_CONTAINER", "dataset")
BLOB_NAME = os.environ.get("BLOB_NAME", "dataset.csv")

try:
    credential = ManagedIdentityCredential()
    client = BlobServiceClient(account_url=STORAGE_ACCOUNT_URL, credential=credential)
    blob = client.get_blob_client(container=CONTAINER_NAME, blob=BLOB_NAME)
    data = blob.download_blob().readall()
    _df = pd.read_csv(io.BytesIO(data))
    unnamed = [c for c in _df.columns if c.startswith("Unnamed")]
    if unnamed:
        _df = _df.drop(columns=unnamed)
except Exception:
    _df = pd.DataFrame()


@app.get("/health")
def health():
    return jsonify({"status": "ok", "records_loaded": len(_df)})


@app.get("/insurance-data")
def get_data():
    if _df.empty:
        abort(503, description="Dataset not available")

    limit = request.args.get("limit", 10, type=int)
    offset = request.args.get("offset", 0, type=int)

    limit = max(1, min(limit, 100))   # wymuszamy zakres 1–100
    offset = max(0, offset)

    slice_ = _df.iloc[offset: offset + limit]
    return jsonify({
        "total": len(_df),
        "offset": offset,
        "limit": limit,
        "data": slice_.where(pd.notna(slice_), None).to_dict(orient="records"),
    })


@app.get("/insurance-data/<int:record_id>")
def get_record(record_id):
    if _df.empty:
        abort(503, description="Dataset not available")

    matches = _df[_df["id"] == record_id]
    if matches.empty:
        abort(404, description=f"Record {record_id} not found")

    return jsonify(matches.iloc[0].where(pd.notna(matches.iloc[0]), None).to_dict())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
