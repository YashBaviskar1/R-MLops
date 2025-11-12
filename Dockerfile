# Use a versioned base image for reproducibility from the Rocker Project
FROM rocker/r-ver:4.3.1

# 1. INSTALL SYSTEM DEPENDENCIES
# Install all system-level dependencies first. This layer rarely changes.
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-venv \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libsodium-dev \
    libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. SET UP PYTHON VIRTUAL ENVIRONMENT
# This is unlikely to change, so we do it early.
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python packages
RUN pip install --upgrade pip
RUN pip install mlflow boto3

# 3. INSTALL R PACKAGES
# This is the most time-consuming step. By doing it before copying app code,
# Docker will cache this layer and not re-run it unless this line changes.
RUN R -e "install.packages(c('plumber', 'mlflow', 'jsonlite', 'dotenv', 'carrier'), repos='https://cloud.r-project.org')"

# 4. PREPARE APP DIRECTORY AND COPY FILES
# Now, copy your application files. Changes here will only re-run this and subsequent layers.
WORKDIR /app
COPY api.R /app/
COPY server.R /app/
COPY .env /app/

# 5. EXPOSE PORT AND DEFINE ENTRYPOINT
EXPOSE 8002
# Use a CMD instead of ENTRYPOINT for more flexibility if you need to override it.
CMD ["Rscript", "/app/server.R"]