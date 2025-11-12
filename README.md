# MLOPs pipeline setup in R 

This is a complete end to end production grade deployement guidelines for **R Models** using **Mlflow tracking** and **MinIO s3 bucket** storage and **SeldonCore** for Deployement 


# Prerequistes setups 
- R envionement to run `Rscript`
- Docker
- Kuberanates setup (kubedm or minikube)
- pip, python envionrment

## Configuration 
Note : For a complete prod pipeline it is reccomanded to setup all this inside k8 enviornment inside the pod for easier config in future 
## local setup for MinIO s3 bucket 
PORT : 8001 
- running using docker 
```bash
docker run -d \
  --name minio \
  -p 8001:9000 \
  -p 8002:9001 \
  -e "MINIO_ROOT_USER=admin" \
  -e "MINIO_ROOT_PASSWORD=admin123" \
  quay.io/minio/minio server /data --console-address ":9001"
```

This will start your MinIO bucket :
- S3 API at : http://localhost:8001
- Web Console at : http://localhost:8002



You can go to the webUI and create a bucket where you want to store the models : 
for example 
`mlflow-artifacts`

## Local setup of MLflow 
PORT : 5000
create a python virtual envionrment and after activting it, install the requirements in the `requirements.txt` (or you can directly `pip install mlflow boto`)
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Export the required credentials for Mlflow to access the MinIO s3 buckets.
```bash
export MLFLOW_S3_ENDPOINT_URL=http://localhost:8001
export AWS_ACCESS_KEY_ID=admin
export AWS_SECRET_ACCESS_KEY=admin123
export AWS_DEFAULT_REGION=us-east-1
```



Start the MLflow server with MinIO artifact store 
```bash
mlflow server \
    --backend-store-uri sqlite:///mlflow.db \
    --default-artifact-root s3://mlflow-artifacts \
    --host 0.0.0.0 \
    --port 5000
```

the MLFLOW UI is visible at : 

`http://localhost:8001`

## Model Traning example in R 

If the setup is correct and its able to work perfectly then 
you can do any model traning in R of your choice. 

**note: One important note here is that Mlflow stores the models with pythonic flavours and in order to store/tag the models it is imp to use `crate` functionality for it, refer to the model_traning.R to see the example**

```bash
Rscript model_traning.R
```

after which you can visit the `http://localhost:8002` and using the RUN id from MLflow to see where the models is stored in the artifact.

note the URI that you got from there, it may look something like this
```bash
s3://mlflow-artifacts/7/79be2b3c0fc443fdb23b06824d576a79/artifacts/model
```


## Model Loading from URI 

There are various ways to test model loading configuration 
you can use something like `preidct.R` 
```R
library(mlflow)
mlflow_set_tracking_uri("http://172.26.95.101:5000")
Sys.setenv(
  AWS_ACCESS_KEY_ID = "admin",               
  AWS_SECRET_ACCESS_KEY = "admin123",        
  MLFLOW_S3_ENDPOINT_URL = "http://127.0.0.1:8001" 
)
model_URI = "s3://mlflow-artifacts/7/79be2b3c0fc443fdb23b06824d576a79/artifacts/model"
model <- mlflow_load_model(model_URI)
# print(model)
print(model_URI)

input <- data.frame(
        "Sepal.Length" = 5.1,
        "Sepal.Width" = 3.5,
        "Petal.Length" = 1.4,
        "Petal.Width" = 0.2
    )

prediction <- mlflow_predict(model = model, data = input)
print(prediction)
```


After configuaring your model URI you can :
```bash
Rscript predict.R
```


if this works, it means your model have been loaded and working well.


## Microservice Creation 

SeldonCore does not by default support has any R Server implementation, it mostly has support for pythonic functions hence we need external microservice to load the model in general

the example of microservice 
`plumber.R`

and to test if the microserice works or not you can create `server.R` which runs on a specific port 
and then do 
`Rscript server.R`

you can verify if your endpoints are working properly or not, you can test out the API endpoints using curl or swagger docs as well


## Containerisation of microservice

If your microservice works fine its time to containerse it, the example is given in `Dockerfile` where you can see the this spefic line :
```bash
RUN install2.r plumber mlflow jsonlite rpart reticulate R6
```

This is used instead of `R -e install.packages('plumber', 'mlflow')` etc, the problem is when you build the docker image the direct installation of packages does not cache it is instead better to use `install2.r` which will install forzen pre-built packages and the building process will be smoother next time essentially 

after doing that you can 
```bash 
docker build -t iris-rmodel:latest .
```

watch the logs 

```bash
docker run iris-rmodel -p 8080:8000
```

if this works perfectly fine after testing, you can push it to your docker hub 

```bash
docker tag myrmodel:latest <your_dockerhub_username>/r-mlflow-model:latest
docker push <your_dockerhub_username>/r-mlflow-model:latest
```




### SeldonCore Setup 

for deploying this model using seldon core, say using minikube 

```bash
kubectl create namespace seldon-system

helm install seldon-core seldon-core-operator \
    --repo https://storage.googleapis.com/seldon-charts \
    --set usageMetrics.enabled=true \
    --namespace seldon-system \
    --set istio.enabled=true
    # You can set ambassador instead with --set ambassador.enabled=true
```