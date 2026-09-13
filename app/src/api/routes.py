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


# Register an HTTP POST endpoint at /ask.
@router.post(
    "/ask",
    response_model=QuestionResponse,
    status_code=status.HTTP_200_OK,
    tags=["Questions"],
)
def ask_question(request: QuestionRequest) -> QuestionResponse:

    # Authentication will be added in a later phase.
    # Currently, this endpoint accepts local requests without credentials.

    # The AI model is also not connected yet.
    # We use a temporary answer to test the API workflow.
    temporary_answer = (
        "The API received your question successfully. "
        "The AI model is not connected yet."
    )

    # If an unexpected problem occurs later, we can return an HTTP error.
    if not temporary_answer:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="The application could not produce an answer.",
        )

    # Build and return the structured response.
    return QuestionResponse(
        question=request.question,
        answer=temporary_answer,
        model="not-configured",
    )