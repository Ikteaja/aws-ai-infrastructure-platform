# API Workflow Guide

## Big Picture

Think of the workflow as a chain:

```text
Client
  |
  | HTTP request
  v
Uvicorn web server
  |
  v
FastAPI application
  |
  v
APIRouter
  |
  v
Endpoint function in routes.py
  |
  v
Pydantic validation
  |
  v
Business logic
  |
  v
JSON response
```

An API endpoint is the combination of an HTTP method and a URL path. The method says what kind of action the client wants; the path identifies the operation.

## The Project Layers

| Layer | Responsibility |
|---|---|
| `routes.py` | Defines HTTP endpoints and handler functions |
| Pydantic models | Validate request and response data |
| `app/src/main.py` | Creates the FastAPI app and includes routers |
| Uvicorn | Runs the Python web application |
| Docker | Packages the application |
| Kubernetes | Runs and exposes application containers |
| Ollama or Bedrock | Generates the AI answer |

## Endpoint Map

The current route definitions are in `app/src/api/routes.py`.

| Request | Handler | Purpose |
|---|---|---|
| `GET /health` | `health_check()` | Confirms the process is alive |
| `GET /ready` | `readiness_check()` | Confirms the app is ready |
| `POST /ask` | `ask_question()` | Accepts a question and returns an answer |

A route connects a public request to a Python function:

```python
@router.get("/health")
def health_check():
    return {"status": "healthy"}
```

This means:

```text
GET /health -> health_check()
```

The route is not the Python function itself. The route is the public HTTP contract that points to the function.

Complete mapping:

```text
GET  /health -> health_check()
GET  /ready  -> readiness_check()
POST /ask    -> ask_question()
```

## Who Uses Each Endpoint?

Regular users normally do not call `/health` or `/ready` directly. They use the business endpoint:

```text
User -> Frontend -> POST /ask -> FastAPI -> AI model
```

The health endpoints are for Kubernetes, load balancers, and monitoring systems:

```text
Kubernetes -> GET /health
Kubernetes -> GET /ready
```

### `/health`: liveness check

`GET /health` answers: "Is the API process alive?" It should be a small and fast check. If it fails repeatedly, Kubernetes can restart the API container.

```text
/health = restart me if the process is broken
```

### `/ready`: readiness check

`GET /ready` answers: "Can this API safely receive traffic?" If it fails, Kubernetes keeps the pod running but temporarily removes it from Service traffic.

Later, this endpoint can check dependencies such as Ollama, a database, or AWS Bedrock:

```text
/health -> 200 OK   (the process is alive)
/ready  -> 503      (a required dependency is unavailable)
```

This prevents users from being routed to a pod that is running but not able to complete requests.

## Request Flow: POST /ask

A client sends:

```http
POST /ask
Content-Type: application/json
```

```json
{
  "question": "What is Kubernetes?"
}
```

FastAPI then:

1. Matches `POST /ask` to `ask_question()`.
2. Converts the JSON body into `QuestionRequest`.
3. Checks that `question` is text and no longer than 1,000 characters.
4. Removes leading and trailing spaces.
5. Rejects an empty question.
6. Runs the handler.
7. Validates the result as `QuestionResponse`.
8. Returns JSON to the client.

Example response:

```json
{
  "question": "What is Kubernetes?",
  "answer": "The API received your question successfully. The AI model is not connected yet.",
  "model": "not-configured"
}
```

The validation flow is:

```text
JSON request
  |
  v
QuestionRequest
  |
  v
field_validator("question")
  |
  v
ask_question(request)
```

The validator removes leading and trailing spaces, rejects an empty question, and rejects text longer than 1,000 characters. Invalid input produces a validation error before the handler runs.

## How Does The Question Propagate?

The current implementation receives and validates the question, but it does not send it to an AI service yet:

```text
Client
  | POST /ask
  | {"question": "What is Kubernetes?"}
  v
FastAPI route: ask_question(request)
  |
  | request.question
  v
QuestionRequest.question
  |
  v
temporary_answer  <- current stopping point
  |
  v
QuestionResponse
  |
  v
Client receives JSON
```

The important line that reads the user's question is:

```python
request.question
```

The current code does not contain an Ollama URL, Bedrock client, model ID, or AI service call. Therefore, the question currently stops inside the FastAPI handler and the response uses `model: "not-configured"`.

### Future propagation after AI integration

When an AI service is added, the route should pass the question to a separate service layer:

```text
Client
  |
  | POST /ask
  v
FastAPI route
  |
  | ai_service.generate_answer(request.question)
  v
AI service layer
  |
  +--> Ollama: HTTP request to http://localhost:11434
  |
  +--> Bedrock: boto3 API call to AWS
  v
Generated answer
  |
  v
QuestionResponse
  |
  v
Client
```

The public endpoint remains `POST /ask`; only the internal provider changes.

### Configuration ownership

```text
routes.py
  = HTTP endpoint, request validation, and response mapping

config.py or environment variables
  = provider, URL, model name, region, and timeouts

ai_service.py
  = common generate_answer(question) interface

ollama_client.py / bedrock_client.py
  = provider-specific implementation

Kubernetes Service
  = network path to the API Pod; it does not call the AI model itself
```

## Handler And Response Relationship

The handler currently returns a temporary answer because an AI model is not connected yet. Later it will call Ollama locally or AWS Bedrock in AWS.

```text
ask_question()
  |
  v
Ollama or AWS Bedrock
  |
  v
Generated answer
  |
  v
QuestionResponse
```

The `response_model=QuestionResponse` declaration means the returned response must contain:

```python
class QuestionResponse(BaseModel):
    question: str
    answer: str
    model: str
```

## Application Wiring

This is the part that connects the route definitions to a running API. The route file creates an `APIRouter`, but the FastAPI application must include that router.

### Current project state

The route definitions are in `app/src/api/routes.py`. The FastAPI application is in `app/src/main.py` and already includes the router.

### Target wiring

The router must be included in a FastAPI application:

```python
from fastapi import FastAPI
from .api.routes import router

app = FastAPI(title="Secure AI Platform API")
app.include_router(router)
```

`include_router(router)` is the connection between the route definitions and the running application. Without it, the route functions exist in Python but are not exposed as URLs.

Start the current application from the project root with the virtual-environment Python:

```powershell
cd C:\Users\iktea\.vscode\aws-ai-infrastructure-platform
.\.venv\Scripts\python.exe -m uvicorn app.src.main:app --reload
```

The `app.src.main:app` notation means:

```text
app.src.main = app/src/main.py
app           = FastAPI variable inside that module
```

Useful URLs:

```text
http://localhost:8000/health
http://localhost:8000/ready
http://localhost:8000/docs
```

`/docs` is FastAPI's interactive API documentation.

### Complete relationship

```text
routes.py
  -> router = APIRouter()
  -> @router.get(...) and @router.post(...)
  -> app/src/main.py imports router
  -> app.include_router(router)
  -> Uvicorn runs app.src.main:app
  -> clients can call the URLs
```

## Kubernetes Relationship

Kubernetes does not create the application endpoints. FastAPI creates them. Kubernetes runs the application and routes traffic to it.

```text
Browser or frontend
  -> Kubernetes Service
  -> API Pod
  -> Uvicorn
  -> FastAPI app
  -> route handler
```

Kubernetes can call the health endpoints as probes:

```text
GET /health -> liveness: is the process alive?
GET /ready  -> readiness: should traffic be sent here?
```

Kubernetes does not create `/health`, `/ready`, or `/ask`. You create those endpoints in Python. Kubernetes only runs the container and sends network traffic to it through a Service.

## Future AI Flow

The current `/ask` handler returns a temporary answer. The future flow will call a model service:

```text
POST /ask
  -> FastAPI route
  -> AI service client
  -> Ollama locally OR AWS Bedrock in AWS
  -> generated answer
  -> QuestionResponse
```

Ollama is useful for local development. AWS Bedrock is the managed AWS option for production model access.

## Automated Testing

Manual browser or PowerShell checks are useful, but repeating them after every code change is inefficient. Automated tests check the API consistently before Docker or Kubernetes deployment.

### Why tests are needed

The tests verify:

- `/health` still works.
- `/ready` still works.
- `/ask` accepts a valid question.
- `/ask` rejects an empty question.
- The response contains the expected fields.

Without automated testing:

```text
Code change -> Docker image -> Kubernetes deployment -> failure discovered late
```

With automated testing:

```text
Code change -> test detects the problem -> pipeline stops
```

This is called **shift-left testing**: find problems early, before deployment.

### Test file and mapping

The tests are in `app/tests/test_api.py`. They use FastAPI's `TestClient`, which loads the application directly in memory instead of using a network port.

```text
Test                              What it protects
test_health_endpoint              /health returns 200 and healthy status
test_readiness_endpoint           /ready returns 200 and ready status
test_ask_endpoint_with_valid...   valid question returns an answer
test_ask_endpoint_removes...      surrounding spaces are cleaned
test_ask_endpoint_rejects_empty   blank questions return 422
test_ask_endpoint_rejects_missing missing question returns 422
test_ask_endpoint_rejects_invalid invalid type returns 422
```

Tests follow three stages:

```text
Arrange -> prepare request data
Act     -> call the endpoint
Assert  -> check the result
```

Example:

```python
request_body = {"question": "What is the policy?"}
response = client.post("/ask", json=request_body)
assert response.status_code == 200
assert response.json()["answer"]
```

An assertion such as `assert response.status_code == 200` means the test passes only when the actual status is 200. A 500 response makes the test fail.

### Run the tests

Stop Uvicorn first with `Ctrl+C` if it is running. From the repository root, with `(.venv)` active, run:

```powershell
python -m pytest .\app\tests -v
```

You can also use the explicit virtual-environment interpreter:

```powershell
.\.venv\Scripts\python.exe -m pytest .\app\tests -v
```

Expected result:

```text
7 passed
```

Uvicorn is not required for these tests because `TestClient(app)` calls the FastAPI application directly in the test process. This makes tests fast, repeatable, independent of port 8000, and suitable for a CI pipeline such as GitHub Actions.

The test-to-deployment workflow is:

```text
FastAPI code -> pytest -> Docker image -> Kubernetes deployment
```

## A Simple Mental Model

```text
Route       = public HTTP contract
Handler     = Python function that performs the work
Model       = shape and validation of data
Uvicorn     = server process that listens for requests
FastAPI app = object that owns the registered routes
Kubernetes  = platform that runs and exposes the server
```

When debugging, follow the request in this order:

1. Is the server running?
2. Is the URL and HTTP method correct?
3. Is the router included in the FastAPI app?
4. Does request validation accept the body?
5. Does the handler complete successfully?
6. Does Kubernetes Service route to the correct Pod?
