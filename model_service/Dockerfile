# Start from the same Python runtime family as the API image.
FROM python:3.12-slim


# Prevent Python from creating .pyc cache files.
ENV PYTHONDONTWRITEBYTECODE=1

# Send application logs directly to the container output.
ENV PYTHONUNBUFFERED=1


# Create a dedicated group and user.
# The application will run without root privileges.
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 \
               --gid appgroup \
               --create-home \
               appuser


# Set the working directory inside the container.
WORKDIR /workspace


# Copy the dependency list before the application code.
# This allows Docker to reuse the dependency installation layer.
COPY model_service/requirements.txt /tmp/requirements.txt


# Install only the packages required to run this service.
RUN python -m pip install \
    --no-cache-dir \
    -r /tmp/requirements.txt


# Copy the package marker and application code.
# Tests and local cache files are not copied into the image.
COPY model_service/__init__.py /workspace/model_service/__init__.py
COPY model_service/main.py /workspace/model_service/main.py


# Run the application as the unprivileged user.
USER 10001:10001


# Document the port used by the application inside the container.
# This instruction alone does not publish the port to your laptop.
EXPOSE 8002


# Check whether the service responds inside its own container.
# Python includes urllib, so installing curl is unnecessary.
HEALTHCHECK --interval=10s \
            --timeout=3s \
            --start-period=10s \
            --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8002/health', timeout=2)" || exit 1


# Start the mock service.
# Listen on all container interfaces so published ports can reach it.
CMD ["python", "-m", "uvicorn", "model_service.main:app", "--host", "0.0.0.0", "--port", "8002"]