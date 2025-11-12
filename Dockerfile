
FROM rocker/r-ver:4.3.3


RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    python3-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*


WORKDIR /app

RUN install2.r plumber mlflow jsonlite rpart reticulate R6
RUN pip3 install mlflow boto3 

COPY plumber.R .
ENV MLFLOW_PYTHON_BIN=/usr/bin/python3
ENV MLFLOW_BIN=/usr/local/bin/mlflow

EXPOSE 8080
CMD ["R", "-e", "pr <- plumber::plumb(file='plumber.R'); pr$run(host='0.0.0.0', port=8080)"]