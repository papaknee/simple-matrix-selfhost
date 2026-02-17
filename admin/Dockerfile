FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install docker CLI for managing containers
RUN apt-get update && \
    apt-get install -y docker.io git && \
    rm -rf /var/lib/apt/lists/*

# Copy application code
COPY app.py .
COPY templates/ templates/
COPY static/ static/

# Create data directory for schedules
RUN mkdir -p /app/data

EXPOSE 5000

CMD ["python", "app.py"]
