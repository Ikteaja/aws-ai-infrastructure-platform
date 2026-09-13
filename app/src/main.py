# Import the FastAPI class.
# We use this class to create our web application.
from fastapi import FastAPI

# Import the router containing our endpoints.
from app.src.api.routes import router


# Create the FastAPI application object.
app = FastAPI(

    # Displayed in the automatic API documentation.
    title="Secure AI Infrastructure Platform API",

    # Short explanation of the API.
    description=(
        "Local API for learning secure AI infrastructure "
        "and model inference operations."
    ),

    # Current application version.
    version="0.1.0",
)


# Register the endpoints from routes.py with the application.
app.include_router(router)