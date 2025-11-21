library(mlflow)

mlflow_set_tracking_uri("http://localhost:5000")
Sys.setenv(
  MLFLOW_S3_ENDPOINT_URL = "http://127.0.0.1:8001",
  AWS_ACCESS_KEY_ID = "admin",
  AWS_SECRET_ACCESS_KEY = "admin123"
)

model_uri <- "s3://mlflow-artifacts/9/6ee2a932beb84a3b875694a36af388a1/artifacts/model"
model <- mlflow_load_model(model_uri)

# Example prediction
input <- data.frame(
  crim = 0.1, zn = 18, indus = 2.3, chas = 0, nox = 0.5,
  rm = 6, age = 65, dis = 4, rad = 1, tax = 296,
  ptratio = 15, black = 390, lstat = 5
)   

prediction <- mlflow_predict(model, input)
print(prediction)

# --------------------------------
# RUN SERVER (only if run directly)
# --------------------------------
