# Use the Rocker image with R 4.3.3 (stable base for R and Plumber)
FROM rocker/r-ver:4.3.3

# Install system dependencies (needed by plumber, httr, xml2, etc.)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    python3-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install R packages needed for the API
RUN install2.r --error \
    plumber \
    mlflow \
    jsonlite \
    randomForest \
    carrier \
    reticulate \
    R6

# Install Python packages for MLflow’s backend communication
RUN pip3 install --no-cache-dir mlflow boto3

# Copy your R API file
COPY test-api.R /app/test-api.R

ENV PATH="/usr/local/bin:$PATH"
ENV MLFLOW_PYTHON_BIN=/usr/bin/python3
ENV MLFLOW_BIN=/usr/local/bin/mlflow
# Expose the port your API will run on
EXPOSE 9000

# Run the Plumber API
CMD ["R", "-e", "pr <- plumber::plumb(file='test-api.R'); pr$run(host='0.0.0.0', port=9000)"]
