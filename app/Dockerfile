# Start from an official lightweight Python image.
FROM python:3.12-slim


# Prevent Python from creating unnecessary .pyc cache files.
ENV PYTHONDONTWRITEBYTECODE=1

# Send Python logs directly to the terminal.
# This is important for Docker and Kubernetes logging.
ENV PYTHONUNBUFFERED=1


# Create a group and user with ID 10001.
# The application should not run with root privileges.
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 \
               --gid appgroup \
               --create-home \
               appuser


# Set the working directory inside the container.
# Following commands will operate from this location.
WORKDIR /workspace


# Copy only the runtime dependency file first.
# Docker can reuse this layer when application code changes.
COPY app/requirements.txt /tmp/requirements.txt


# Install the Python runtime dependencies.
# --no-cache-dir prevents pip from keeping unnecessary package files.
RUN python -m pip install \
    --no-cache-dir \
    -r /tmp/requirements.txt


# Copy the application package into the container.
COPY app /workspace/app


# Change from root to the unprivileged application user.
USER 10001:10001


# Document that the application listens on port 8000.
EXPOSE 8000


# Check whether the application remains healthy.
# urllib is included with Python, so no additional tool is needed.
HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=10s \
            --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1


# Define the command executed when the container starts.
CMD ["python", "-m", "uvicorn", "app.src.main:app", "--host", "0.0.0.0", "--port", "8000"]