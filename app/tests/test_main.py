import pandas as pd
import pytest
import app.main as main_module
from app.main import app

client = app.test_client()

SAMPLE_DF = pd.DataFrame([
    {
        "id": 0,
        "Age": 19.0,
        "Gender": "Woman",
        "Premium Amount": 2869.0,
        "Policy Type": "Premium",
    },
    {
        "id": 1,
        "Age": 39.0,
        "Gender": "Woman",
        "Premium Amount": 1483.0,
        "Policy Type": "Standard Coverage",
    },
])


@pytest.fixture(autouse=True)
def patch_df(monkeypatch):
    monkeypatch.setattr(main_module, "_df", SAMPLE_DF)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.data == b"ok, loaded 2 records"


def test_get_data_default():
    response = client.get("/insurance-data")
    assert response.status_code == 200
    assert len(response.get_json()) == 2


