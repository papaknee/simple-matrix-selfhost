FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install git and Docker CLI (lightweight approach)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        gnupg && \
    # Install Docker CLI only (not the daemon)
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    # Clean up
    rm -rf /var/lib/apt/lists/*

# Copy application code
COPY app.py .
COPY templates/ templates/
COPY static/ static/

# Create data directory for schedules
RUN mkdir -p /app/data

EXPOSE 5000

CMD ["python", "app.py"]
