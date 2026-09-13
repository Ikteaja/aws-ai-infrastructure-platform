# Import TestClient from FastAPI.
# TestClient acts like a user or application sending HTTP requests.
from fastapi.testclient import TestClient

# Import our FastAPI application object from main.py.
from app.src.main import app


# Create one test client connected to our application.
# It runs the API directly in memory.
# It does not start a real web server on port 8000.
client = TestClient(app)


# Test whether the health endpoint works.
def test_health_endpoint():

    # ACT:
    # Send an HTTP GET request to /health.
    response = client.get("/health")

    # ASSERT:
    # Confirm that the API returned HTTP status 200.
    assert response.status_code == 200

    # Convert the JSON response into a Python dictionary.
    response_body = response.json()

    # Confirm that the status value is correct.
    assert response_body["status"] == "healthy"

    # Confirm that the expected service name is returned.
    assert response_body["service"] == "secure-ai-platform-api"


# Test whether the readiness endpoint works.
def test_readiness_endpoint():

    # Send an HTTP GET request to /ready.
    response = client.get("/ready")

    # Confirm that the request succeeded.
    assert response.status_code == 200

    # Confirm that the complete JSON response is correct.
    assert response.json() == {
        "status": "ready",
    }


# Test /ask with a valid question.
def test_ask_endpoint_with_valid_question():

    # ARRANGE:
    # Prepare the JSON request body.
    request_body = {
        "question": "What is the password policy?"
    }

    # ACT:
    # Send the JSON body to POST /ask.
    response = client.post(
        "/ask",
        json=request_body,
    )

    # ASSERT:
    # Confirm that the request succeeded.
    assert response.status_code == 200

    # Convert the response JSON into a Python dictionary.
    response_body = response.json()

    # Confirm that the API returned the original question.
    assert response_body["question"] == request_body["question"]

    # Confirm that an answer field exists.
    assert "answer" in response_body

    # Confirm that the answer is not empty.
    assert response_body["answer"]

    # The model is not connected yet.
    assert response_body["model"] == "not-configured"


# Test whether spaces are removed around a question.
def test_ask_endpoint_removes_extra_spaces():

    # The question contains unnecessary spaces.
    request_body = {
        "question": "   What is the password policy?   "
    }

    # Send the request.
    response = client.post(
        "/ask",
        json=request_body,
    )

    # Confirm that it succeeded.
    assert response.status_code == 200

    # Confirm that the returned question has been cleaned.
    assert response.json()["question"] == "What is the password policy?"


# Test whether an empty question is rejected.
def test_ask_endpoint_rejects_empty_question():

    # Prepare an invalid question containing only spaces.
    request_body = {
        "question": "   "
    }

    # Send the invalid request.
    response = client.post(
        "/ask",
        json=request_body,
    )

    # FastAPI uses status 422 for request-validation errors.
    assert response.status_code == 422


# Test whether a missing question field is rejected.
def test_ask_endpoint_rejects_missing_question():

    # Send an empty JSON object.
    response = client.post(
        "/ask",
        json={},
    )

    # The required question field is missing.
    assert response.status_code == 422


# Test whether the wrong data type is rejected.
def test_ask_endpoint_rejects_invalid_type():

    # A list is not a valid question.
    request_body = {
        "question": ["password", "policy"]
    }

    # Send the invalid request.
    response = client.post(
        "/ask",
        json=request_body,
    )

    # Confirm that validation rejected it.
    assert response.status_code == 422