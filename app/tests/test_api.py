# Import HTTPX to create simulated model responses and network errors.
import httpx

# Import pytest to provide reusable test setup.
import pytest

# Import TestClient from FastAPI.
# TestClient acts like a user or application sending HTTP requests.
from fastapi.testclient import TestClient

# Import our FastAPI application object from main.py.
from app.src.main import app


# Create one test client connected to our application.
# It runs the API directly in memory.
# It does not start a real web server on port 8000.
client = TestClient(app)


# Automatically replace outgoing model requests during testing.
# autouse=True means pytest runs this setup before every test.
@pytest.fixture(autouse=True)
def mock_model_request(monkeypatch):

    # Configure a predictable address for tests.
    # No real request will be sent to this address.
    monkeypatch.setenv(
        "MODEL_BASE_URL",
        "http://model-service.test:8002",
    )

    # Replace the outgoing request with a simulated response.
    def fake_post(url, *, json, timeout):

        # Confirm that the API calls the expected model endpoint.
        assert url == "http://model-service.test:8002/generate"

        # Confirm that the API sends a text prompt.
        assert isinstance(json["prompt"], str)

        # Confirm that the prompt is not empty.
        assert json["prompt"]

        # Confirm that surrounding spaces have been removed.
        assert json["prompt"] == json["prompt"].strip()

        # Confirm that the API sets the expected network timeout.
        assert timeout == 5.0

        # Return the response that our API will process.
        # Attach a request so response.raise_for_status() can work.
        return httpx.Response(
            status_code=200,
            json={
                "answer": "Test answer from the model.",
                "model": "mock-model-v1",
            },
            request=httpx.Request("POST", url),
        )

    # Apply the replacement for each test.
    # pytest restores the original function afterward.
    monkeypatch.setattr(
        "app.src.api.routes.httpx.post",
        fake_post,
    )


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
    # Currently, this endpoint does not check model availability.
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
    # response contains the HTTP status, headers and response body.
    assert response.status_code == 200

    # Convert the JSON response into a Python dictionary.
    # response_body contains the returned question, answer and model.
    response_body = response.json()

    # Confirm that the API returned the original question.
    assert response_body["question"] == request_body["question"]

    # Confirm that an answer field exists.
    assert "answer" in response_body

    # Confirm that the answer is not empty.
    assert response_body["answer"]

    # Confirm that the API returns the simulated model's answer.
    assert response_body["answer"] == "Test answer from the model."

    # Confirm that the API returns the simulated model's name.
    assert response_body["model"] == "mock-model-v1"


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


# Test whether the API handles an unavailable model service.
def test_ask_returns_503_when_model_unavailable(monkeypatch):

    # ARRANGE:
    # Simulate a model service that refuses the connection.
    def unavailable_post(url, *, json, timeout):

        # Raise the same type of error as a failed connection.
        raise httpx.ConnectError(
            "Connection refused",
            request=httpx.Request("POST", url),
        )

    # Replace the fixture's successful response for this test only.
    monkeypatch.setattr(
        "app.src.api.routes.httpx.post",
        unavailable_post,
    )

    # ACT:
    # Send a valid question to the API.
    response = client.post(
        "/ask",
        json={
            "question": "What is Kubernetes?"
        },
    )

    # ASSERT:
    # Confirm that the API handles the connection failure.
    assert response.status_code == 503

    # Confirm that the response explains the problem.
    assert response.json() == {
        "detail": "The model service is unavailable.",
    }