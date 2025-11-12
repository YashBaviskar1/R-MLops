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
