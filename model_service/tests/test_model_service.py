# Import TestClient from FastAPI.
# It sends requests directly to the application in memory.
from fastapi.testclient import TestClient

# Import the mock model application.
# This is separate from the main API in app/src/main.py.
from model_service.main import app


# Create a test client for the actual mock service code.
# No Uvicorn process or listening port is required.
client = TestClient(app)


# Test whether the mock service health endpoint works.
def test_model_health_endpoint():

    # ACT:
    # Send an HTTP GET request to /health.
    response = client.get("/health")

    # ASSERT:
    # Confirm that the request succeeded.
    assert response.status_code == 200

    # Confirm that the correct service identifies itself as healthy.
    assert response.json() == {
        "status": "healthy",
        "service": "mock-model-service",
    }


# Test generation with a valid prompt.
def test_generate_with_valid_prompt():

    # ARRANGE:
    # Prepare the request expected by the model service.
    # This service accepts "prompt"; the main API accepts "question".
    request_body = {
        "prompt": "What is Kubernetes?"
    }

    # ACT:
    # Execute the actual /generate endpoint.
    response = client.post(
        "/generate",
        json=request_body,
    )

    # ASSERT:
    # Confirm that the request succeeded.
    assert response.status_code == 200

    # Convert the response JSON into a Python dictionary.
    response_body = response.json()

    # Confirm that the service returns its expected mock message.
    assert response_body["answer"] == (
        "Mock response: received your prompt 'What is Kubernetes?'. "
        "No real AI model is connected."
    )

    # Confirm that the response identifies the mock model.
    assert response_body["model"] == "mock-model-v1"


# Test whether surrounding spaces are removed from the prompt.
def test_generate_removes_extra_spaces():

    # ARRANGE:
    # Add unnecessary spaces around the prompt.
    request_body = {
        "prompt": "   What is Kubernetes?   "
    }

    # ACT:
    # Send the padded prompt.
    response = client.post(
        "/generate",
        json=request_body,
    )

    # ASSERT:
    # Confirm that the request succeeded.
    assert response.status_code == 200

    # The answer should contain the cleaned prompt.
    # Spaces inside the quoted prompt would make this assertion fail.
    assert response.json()["answer"] == (
        "Mock response: received your prompt 'What is Kubernetes?'. "
        "No real AI model is connected."
    )


# Test whether a whitespace-only prompt is rejected.
def test_generate_rejects_empty_prompt():

    # ARRANGE:
    # This contains characters but no meaningful text.
    request_body = {
        "prompt": "   "
    }

    # ACT:
    # Send the invalid prompt.
    response = client.post(
        "/generate",
        json=request_body,
    )

    # ASSERT:
    # The custom validator should reject whitespace-only input.
    assert response.status_code == 422


# Test whether the required prompt field must be present.
def test_generate_rejects_missing_prompt():

    # ACT:
    # Send an empty JSON object without the prompt field.
    response = client.post(
        "/generate",
        json={},
    )

    # ASSERT:
    # FastAPI should report a request-validation error.
    assert response.status_code == 422


# Test whether the prompt must be text.
def test_generate_rejects_invalid_type():

    # ARRANGE:
    # A list is not a valid text prompt.
    request_body = {
        "prompt": ["What", "is", "Kubernetes?"]
    }

    # ACT:
    # Send the incorrect data type.
    response = client.post(
        "/generate",
        json=request_body,
    )

    # ASSERT:
    # The request should be rejected.
    assert response.status_code == 422


# Test whether prompts longer than 1,000 characters are rejected.
def test_generate_rejects_too_long_prompt():

    # ARRANGE:
    # Repeat one character 1,001 times to exceed the limit.
    request_body = {
        "prompt": "a" * 1001
    }

    # ACT:
    # Send the oversized prompt.
    response = client.post(
        "/generate",
        json=request_body,
    )

    # ASSERT:
    # The maximum-length validation should reject the request.
    assert response.status_code == 422