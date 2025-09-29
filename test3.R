library(mlflow)
Sys.setenv(
  AWS_ACCESS_KEY_ID = "root",               
  AWS_SECRET_ACCESS_KEY = "12345678",        
  MLFLOW_S3_ENDPOINT_URL = "http://127.0.0.1:9000" 
)
model_URI = "s3://mlflow-artifacts/1/d2cbc5aedb1b43d79da1f989b437028c/artifacts/rf_model"
model <- mlflow_load_model(model_URI)
# print(model)


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