# FastAPI provides the web application and HTTP endpoints.
from fastapi import FastAPI

# Pydantic validates incoming requests and outgoing responses.
from pydantic import BaseModel, Field, field_validator


# This application runs separately from your existing API.
app = FastAPI(
    title="Mock Model Service",
    description="A predictable test service. No real AI model is loaded.",
    version="0.1.0",
)


# Define the JSON accepted by POST /generate.
class GenerateRequest(BaseModel):

    # Require a text prompt between 1 and 1,000 characters.
    prompt: str = Field(min_length=1, max_length=1000)

    # Reject prompts containing only whitespace.
    @field_validator("prompt")
    @classmethod
    def validate_prompt(cls, value: str) -> str:
        # Remove surrounding whitespace.
        cleaned_prompt = value.strip()

        # Reject the request if no text remains.
        if not cleaned_prompt:
            raise ValueError("Prompt cannot be empty.")

        return cleaned_prompt


# Define the JSON returned by POST /generate.
class GenerateResponse(BaseModel):

    # The predefined answer returned by this mock.
    answer: str

    # Identify the service as a mock rather than a real model.
    model: str


# Check that the model service is running.
@app.get("/health")
def health_check() -> dict[str, str]:
    return {
        "status": "healthy",
        "service": "mock-model-service",
    }


# Accept a prompt and return a predictable response.
@app.post("/generate", response_model=GenerateResponse)
def generate(request: GenerateRequest) -> GenerateResponse:

    # Echo the validated prompt to demonstrate request handling.
    # This is string formatting, not AI inference.
    answer = (
        f"Mock response: received your prompt '{request.prompt}'. "
        "No real AI model is connected."
    )

    # FastAPI converts this response object into JSON.
    return GenerateResponse(
        answer=answer,
        model="mock-model-v1",
    )