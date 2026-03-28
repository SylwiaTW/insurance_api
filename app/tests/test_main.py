import pandas as pd
import pytest
import app.main as main_module
from app.main import app

client = app.test_client()

SAMPLE_DF = pd.DataFrame([
    {"id": 0, "Age": 19.0, "Gender": "Woman", "Premium Amount": 2869.0, "Policy Type": "Premium"},
    {"id": 1, "Age": 39.0, "Gender": "Woman", "Premium Amount": 1483.0, "Policy Type": "Standard Coverage"},
])


@pytest.fixture(autouse=True)
def patch_df(monkeypatch):
    monkeypatch.setattr(main_module, "_df", SAMPLE_DF)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"
    assert response.get_json()["records_loaded"] == 2


def test_get_data_default():
    response = client.get("/insurance-data")
    assert response.status_code == 200
    body = response.get_json()
    assert body["total"] == 2
    assert len(body["data"]) == 2


def test_get_data_limit():
    response = client.get("/insurance-data?limit=1")
    assert response.status_code == 200
    assert len(response.get_json()["data"]) == 1


def test_get_data_offset():
    response = client.get("/insurance-data?limit=1&offset=1")
    assert response.status_code == 200
    assert response.get_json()["data"][0]["id"] == 1


def test_get_record_found():
    response = client.get("/insurance-data/0")
    assert response.status_code == 200
    assert response.get_json()["Gender"] == "Woman"


def test_get_record_not_found():
    response = client.get("/insurance-data/999")
    assert response.status_code == 404
