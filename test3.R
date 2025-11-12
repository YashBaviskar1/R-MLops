library(mlflow)
mlflow_set_tracking_uri("http://172.26.95.101:5000")
Sys.setenv(
  AWS_ACCESS_KEY_ID = "admin",               
  AWS_SECRET_ACCESS_KEY = "admin123",        
  MLFLOW_S3_ENDPOINT_URL = "http://127.0.0.1:8001" 
)
model_URI = "s3://mlflow-artifacts/7/442cc39313bf4c34b9ef7ee17379b74c/artifacts/model"
model <- mlflow_load_model(model_URI)
# print(model)
print(model_URI)

input <- data.frame(
  crim = 0.1,
  zn = 0,
  indus = 8.14,
  chas = 0,
  nox = 0.5,
  rm = 6.0,
  age = 65,
  dis = 4.0,
  rad = 4,
  tax = 307,
  ptratio = 18,
  black = 390,
  lstat = 12
)

prediction <- mlflow_predict(model = model, data = input)
print(prediction)