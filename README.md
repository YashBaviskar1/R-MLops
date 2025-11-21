
---
#  End-to-End MLOps Pipeline for R Models


This project implements a complete MLOps pipeline for training, tracking, and serving R machine learning models. It addresses the specific engineering challenges of "Polyglot MLOps"—integrating R-based data science workflows with Python-native MLOps tools (MLflow) and cloud-native orchestration (Kubernetes).

The system supports two modes of operation:

1.  **Cloud-Native Pipeline:** A fully distributed system using Kubernetes Jobs for training, persistent storage for artifacts, and the Sidecar pattern for production serving. [Cloud-Native Kubernetes Pipeline](Cloud-Native/README.md)
2.  **Local Development:** A standalone Docker-based workflow for rapid testing and debugging on a local machine. (Continue Below)

---

##  Overview

This guide walks through building a **production-ready pipeline** for training, tracking, storing, and deploying **R machine learning models** using:

* **MLflow** for experiment tracking and model registry
* **MinIO** for S3-compatible artifact storage
* **Seldon Core** for scalable, Kubernetes-native model serving

The workflow includes:

1. Model training and logging with MLflow (in R)
2. Artifact storage in MinIO
3. Containerized R inference service
4. Deployment to Kubernetes via Seldon Core

---

##  Prerequisites

Make sure you have the following installed:

* R environment (≥ 4.0)
* Docker
* Kubernetes (via **minikube** or **kubeadm**)
* Python 3 + `pip` for MLflow
* Basic shell and kubectl access

---

##  1. Set Up MinIO (S3 Bucket)

**Port:** `8001` (S3 API) / `8002` (Console)

Run MinIO locally with Docker:

```bash
docker run -d \
  --name minio \
  -p 8001:9000 \
  -p 8002:9001 \
  -e "MINIO_ROOT_USER=admin" \
  -e "MINIO_ROOT_PASSWORD=admin123" \
  quay.io/minio/minio server /data --console-address ":9001"
```

Once started:

* S3 API → [http://localhost:8001](http://localhost:8001)
* Web Console → [http://localhost:8002](http://localhost:8002)

In the web UI, create a bucket named, for example, **`mlflow-artifacts`**.

---

##  2. Set Up MLflow Server

**Port:** `5000`

### Create a virtual environment and install dependencies:

```bash
python -m venv venv
source venv/bin/activate
pip install mlflow boto3
```

### Export MinIO credentials:

```bash
export MLFLOW_S3_ENDPOINT_URL=http://localhost:8001
export AWS_ACCESS_KEY_ID=admin
export AWS_SECRET_ACCESS_KEY=admin123
export AWS_DEFAULT_REGION=us-east-1
```

### Start MLflow:

```bash
mlflow server \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root s3://mlflow-artifacts \
  --host 0.0.0.0 \
  --port 5000
```

* MLflow UI → [http://localhost:5000](http://localhost:5000)

---

##  3. Train and Log an R Model

Train a simple model and log it to MLflow:

```bash
Rscript model_training.R
```

 **Important:**
MLflow stores models in *Pythonic* format. To ensure compatibility, R models should be logged using the **`crate`** package. See `model_training.R` for a working example.

After the run completes, check the MLflow UI or MinIO console to locate your artifact path, e.g.:

```
s3://mlflow-artifacts/7/79be2b3c0fc443fdb23b06824d576a79/artifacts/model
```

---

##  4. Test Model Loading Locally

You can verify the artifact by running:

```bash
Rscript predict.R
```

Or, containerized:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=admin \
  -e AWS_SECRET_ACCESS_KEY=admin123 \
  -e MLFLOW_S3_ENDPOINT_URL=http://host.docker.internal:8001 \
  -e MODEL_URI=s3://mlflow-artifacts/.../model \
  <your_dockerhub_username>/r-mlflow-model:latest Rscript predict.R
```

If this prints valid predictions, your model artifacts and MinIO access are working correctly.

---

##  5. Create an R Microservice with `plumber`

Seldon Core doesn’t natively host R models; instead, you wrap them in a lightweight REST API using [`plumber`](https://www.rplumber.io/).

Example `plumber.R`:

```r
library(plumber)
library(mlflow)

pr <- plumber$new()

pr$handle("POST", "/predict", function(req, res){
  model <- mlflow_load_model(Sys.getenv("MODEL_URI"))
  data <- jsonlite::fromJSON(req$postBody)
  pred <- mlflow_predict(model, data)
  list(prediction = pred)
})

pr$run(host="0.0.0.0", port=8000)
```

---

##  6. Containerize the R Microservice

Create a `Dockerfile`:

```dockerfile
FROM rocker/r-ver:4.2.2

RUN apt-get update && apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev

# install2.r gives cached builds and faster Docker layers
RUN install2.r plumber mlflow jsonlite rpart reticulate R6 crate aws.s3

WORKDIR /app
COPY . /app

EXPOSE 8000
CMD ["Rscript", "plumber.R"]
```

Build and run locally:

```bash
docker build -t iris-rmodel:latest .
docker run -p 8000:8000 iris-rmodel:latest
```

Then test:

```bash
curl -X POST http://localhost:8000/predict \
  -H 'Content-Type: application/json' \
  -d '{"Sepal.Length":5.1,"Sepal.Width":3.5,"Petal.Length":1.4,"Petal.Width":0.2}'
```

---

##  7. Push Image to Docker Hub

```bash
docker tag iris-rmodel:latest <your_dockerhub_username>/r-mlflow-model:latest
docker push <your_dockerhub_username>/r-mlflow-model:latest
```

---

## 8. Deploy on Kubernetes with Seldon Core

Install Seldon Core:

```bash
kubectl create namespace seldon-system

helm install seldon-core seldon-core-operator \
  --repo https://storage.googleapis.com/seldon-charts \
  --set usageMetrics.enabled=true \
  --set istio.enabled=true \
  --namespace seldon-system
```

Check that it’s running:

```bash
kubectl get pods -n seldon-system
```

---

##  9. Deploy the R Model with Seldon

Example deployment manifest (`seldon-deployment.yaml`):

```yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: r-mlflow-model
  namespace: seldon
spec:
  name: rmodel-deploy
  predictors:
  - name: default
    replicas: 1
    graph:
      name: rmodel
      type: MODEL
      endpoint:
        type: REST
    componentSpecs:
    - spec:
        containers:
        - name: rmodel
          image: <your_dockerhub_username>/r-mlflow-model:latest
          imagePullPolicy: Always
          ports:
          - containerPort: 8000
          env:
          - name: MLFLOW_TRACKING_URI
            value: "http://mlflow:5000"
          - name: MLFLOW_S3_ENDPOINT_URL
            value: "http://minio:9000"
          - name: AWS_ACCESS_KEY_ID
            valueFrom:
              secretKeyRef:
                name: minio-secret
                key: accesskey
          - name: AWS_SECRET_ACCESS_KEY
            valueFrom:
              secretKeyRef:
                name: minio-secret
                key: secretkey
          - name: MODEL_URI
            value: "s3://mlflow-artifacts/.../model"
```

Apply it:

```bash
kubectl apply -f seldon-deployment.yaml
kubectl get pods -n seldon
```

---

##  10. Test the Deployed Endpoint

Forward the service port:

```bash
kubectl get svc -n seldon
kubectl port-forward -n seldon svc/r-mlflow-model-default 8000:8000
```

Then test with:

```bash
curl -X POST http://localhost:8000/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'
```

Expected output:

```json
{"data":{"names":["prediction"],"ndarray":["setosa"]}}
```

---

##  Notes & Recommendations

* Use **`install2.r`** instead of `install.packages()` inside Docker for faster caching.
* Add **readiness and liveness probes** to production manifests.
* For secure setups, store credentials in **Kubernetes Secrets**.
* For multi-model management, integrate with **MLflow registry** and **Seldon Model Gateway**.

---
