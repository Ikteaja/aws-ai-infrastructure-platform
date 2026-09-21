
# Read configuration from environment variables.
import os
# Send HTTP requests to the model service.
import httpx
# Import APIRouter from FastAPI.
# A router groups related API endpoints together.
from fastapi import APIRouter, HTTPException, status

# Import BaseModel and Field from Pydantic.
# Pydantic checks whether incoming JSON has the correct structure.
from pydantic import BaseModel, Field, field_validator


# Create a router object.
# The endpoints below will be registered with this router.
router = APIRouter()


# Define the expected request body for POST /ask.
# BaseModel tells Pydantic that this class describes JSON data.
class QuestionRequest(BaseModel):

    # The request must contain a field named "question".
    # It must be text with no more than 1,000 characters.
    question: str = Field(
        ...,
        max_length=1000,
        description="The question that the user wants to ask.",
    )

    # This validator runs before the API processes the question.
    # It provides additional validation for empty spaces.
    @field_validator("question")
    @classmethod
    def validate_question(cls, value: str) -> str:

        # Remove spaces from the beginning and end.
        cleaned_question = value.strip()

        # Reject a question that is empty after removing spaces.
        if not cleaned_question:
            raise ValueError("Question cannot be empty.")

        # Return the cleaned value.
        # This becomes the value stored inside the request object.
        return cleaned_question


# Define the response structure for POST /ask.
class QuestionResponse(BaseModel):

    # Return the original validated question.
    question: str

    # Return the generated answer.
    answer: str

    # Identify which model produced the answer.
    model: str


# Register an HTTP GET endpoint at /health.
@router.get(
    "/health",
    status_code=status.HTTP_200_OK,
    tags=["System"],
)
def health_check() -> dict[str, str]:

    # Return a small JSON response.
    # This proves that the Python process and web server are alive.
    return {
        "status": "healthy",
        "service": "secure-ai-platform-api",
    }


# Register an HTTP GET endpoint at /ready.
@router.get(
    "/ready",
    status_code=status.HTTP_200_OK,
    tags=["System"],
)
def readiness_check() -> dict[str, str]:

    # Later, this endpoint will check the model and database.
    # For now, the API has no external dependencies.
    return {
        "status": "ready",
    }


#Register an HTTP POST endpoint at /ask.
# Validate the response received from the model service.
class ModelResponse(BaseModel):
    answer: str = Field(min_length=1)
    model: str = Field(min_length=1)


@router.post(
    "/ask",
    response_model=QuestionResponse,
    status_code=status.HTTP_200_OK,
    tags=["Questions"],
)
def ask_question(request: QuestionRequest) -> QuestionResponse:

    # Use the configured address, with a default for our local lab.
    model_url = os.getenv(
        "MODEL_BASE_URL",
        "http://127.0.0.1:8002",
    ).rstrip("/")

    try:
        # Translate the API's "question" field into the model's "prompt".
        # Set a five-second timeout for network operations.
        response = httpx.post(
            f"{model_url}/generate",
            json={"prompt": request.question},
            timeout=5.0,
        )

        # Raise an error if the model returns a non-success status.
        response.raise_for_status()

        # Check that the response contains a valid answer and model name.
        result = ModelResponse.model_validate(response.json())

    except httpx.TimeoutException as exc:
        # The model took too long to respond.
        raise HTTPException(
            status_code=504,
            detail="The model service timed out.",
        ) from exc

    except httpx.RequestError as exc:
        # Examples: service stopped, connection refused, DNS failure.
        raise HTTPException(
            status_code=503,
            detail="The model service is unavailable.",
        ) from exc

    except httpx.HTTPStatusError as exc:
        # The model responded, but its HTTP status indicated failure.
        raise HTTPException(
            status_code=502,
            detail="The model service returned an error.",
        ) from exc

    except ValueError as exc:
        # The response was invalid JSON or failed schema validation.
        raise HTTPException(
            status_code=502,
            detail="The model service returned an invalid response.",
        ) from exc

    # Preserve the existing public API response format.
    return QuestionResponse(
        question=request.question,
        answer=result.answer,
        model=result.model,
    )
