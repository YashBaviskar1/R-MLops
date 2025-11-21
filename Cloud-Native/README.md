
-----

# End-to-End MLOps Pipeline in Cloud Native Enviornment: R, Kubernetes, and Seldon Core

## Overview

This project implements a cloud-native MLOps pipeline for training and serving R models within a Kubernetes environment. Unlike standard Python-based pipelines, this architecture solves the specific challenges of "Polyglot MLOps" (integrating R with Python-native tools) and distributed orchestration.

The pipeline automates the lifecycle from **Model Training** (Batch Jobs) to **Artifact Storage** (Object Store) to **Production Serving** (Sidecar Pattern).

-----

## Architecture

The system allows for full decoupling of compute, storage, and serving layers:

1.  **Storage Layer (MinIO):** A self-hosted, S3-compatible object store with Persistent Volumes (PVC) ensures model artifacts survive pod restarts.
2.  **Tracking Layer (MLflow):** A centralized tracking server backed by S3.
3.  **Compute Layer (K8s Job):** An ephemeral R-based container that trains the model, logs metrics, pushes the artifact to S3, and terminates.
4.  **Serving Layer (Seldon Core):** Uses the **Sidecar Pattern** to inject a traffic manager alongside the R inference container.

-----

##  Tech Stack

  * **Language:** R (primary), Python (for MLflow/Boto3 backend bindings)
  * **Orchestration:** Kubernetes (Minikube)
  * **Model Serving:** Seldon Core Operator
  * **Artifact Store:** MinIO (S3 Compatible)
  * **Experiment Tracking:** MLflow
  * **API Framework:** Plumber (R)

-----

##  Repository Structure

```text
├── infra/
│   ├── 1-common-secret.yaml     # Shared AWS/S3 credentials
│   ├── 2-minio-infra.yaml       # MinIO Deployment + Service + PVC
│   ├── 3-mlflow-infra.yaml      # MLflow Server (Pinned Version)
│   └── 4-pipeline-pvc.yaml      # Shared Volume for Job Handoffs
├── training/
│   ├── Dockerfile.train         # Hybrid Image (R + Python Env)
│   ├── train.R                  # Training script with MLflow logging
│   └── 5-training-job.yaml      # Kubernetes Job Manifest
├── serving/
│   ├── Dockerfile.serve         # Inference Image (Exposes Port 9000)
│   ├── plumber.R                # API Definition
│   └── 6-seldon-deploy.yaml     # SeldonDeployment Manifest
└── README.md
```

-----

##  Step-by-Step Deployment Guide

### Phase 1: Infrastructure Setup

We establish the "Data Center" components first.

```bash
# 1. Create Namespaces
kubectl create namespace seldon-system

# 2. Install Seldon Operator via Helm
helm install seldon-core seldon-core-operator \
  --repo https://storage.googleapis.com/seldon-charts \
  --set usageMetrics.enabled=true \
  --namespace seldon-system

# 3. Deploy Storage & Tracking (Default Namespace)
kubectl apply -f infra/
```

*Verification:* Ensure `minio` and `mlflow` services are running. Access MinIO UI via port-forward to create the `mlflow-artifacts` bucket.

### Phase 2: Model Training (The Batch Job)

The training job uses a custom Docker image that installs R packages and the necessary Python backend drivers (`boto3`) to communicate with MinIO.

**Key Engineering Decision:**

  * **Challenge:** R's `mlflow` library relies on a system-level Python installation to handle S3 uploads.
  * **Solution:** Created a "Hybrid Dockerfile" that installs R, Python, Pip, and Boto3, and injects `MLFLOW_PYTHON_BIN` via Environment Variables.

<!-- end list -->

```bash
# Run the training job
kubectl apply -f training/5-training-job.yaml

# Check logs for success
kubectl logs job/r-training-job
```

*Output:* The job logs the model to MinIO and prints the `s3://` URI.

### Phase 3: Model Serving (The Sidecar Pattern)

We deploy the model using Seldon Core.

**Key Engineering Decision:**

  * **Challenge (The Sidecar Collision):** Seldon's executor sidecar defaults to Port 8000. Our R Plumber API also defaulted to Port 8000. This caused an `Address already in use` crash loop.
  * **Solution:** We re-architected the serving container to bind to **Port 9000**, while configuring the Seldon YAML to forward traffic from 8000 (Public) -\> 9000 (Internal).

<!-- end list -->

```bash
# Update 6-seldon-deploy.yaml with the S3 URI from Phase 2
kubectl apply -f serving/6-seldon-deploy.yaml
```

-----

##  Testing the API

We use the Seldon Ambassador port (8000) to access the model. This ensures we get metrics and logging, rather than hitting the raw container directly.

**1. Port Forward:**

```bash
kubectl port-forward svc/r-mlflow-model-default 8000:8000
```

**2. Send Prediction Request:**

```bash
curl -X POST http://localhost:8000/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'
```

**Response:**

```json
{"data":{"names":["prediction"],"ndarray":["setosa"]}}
```

-----

##  Troubleshooting & Lessons Learned

### 1\. The "Polyglot Tax"

  * **Issue:** `ModuleNotFoundError: No module named 'boto3'` inside the R container.
  * **Fix:** R containers used for MLOps must explicitly include the Python runtime and `boto3` library.

### 2\. DNS & Service Discovery

  * **Issue:** `Connection Refused` when using `localhost`.
  * **Fix:** In Kubernetes, Pods communicate via CoreDNS. Replaced `localhost` with `http://minio-service:9000`.

### 3\. S3 Path Style Access

  * **Issue:** MinIO rejected connections from the R SDK.
  * **Fix:** MinIO requires "Path Style" access (e.g., `host/bucket`). We injected `AWS_S3_PATH_STYLE_ACCESS=true` into the deployment manifest.

### 4\. Ephemeral Storage

  * **Issue:** `mlflow_save_model()` saved files to the pod's local disk, which vanished when the job finished.
  * **Fix:** Switched to `mlflow_log_model()`, which immediately uploads artifacts to the remote Object Store (MinIO).

-----

