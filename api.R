library(mlflow)
library(plumber)
library(jsonlite)
library(dotenv)
load_dot_env(".env")
MLflow <- Sys.getenv("MLFLOW_SERVER")
mlflow_set_tracking_uri(MLflow)
Sys.setenv(
  AWS_ACCESS_KEY_ID  = Sys.getenv("AWS_ACCESS_KEY_ID"),
  AWS_SECRET_ACCESS_KEY = Sys.getenv("AWS_SECRET_ACCESS_KEY"),
  MLFLOW_S3_ENDPOINT_URL = Sys.getenv("MLFLOW_S3_ENDPOINT_URL")
)
model_URI <- Sys.getenv("MODEL_URI")
model <- mlflow_load_model(model_URI)
print(model_URI)
#* @post /predict
#* @serializer unboxedJSON
function(req) {
  input <- as.data.frame(jsonlite::fromJSON(req$postBody))
  prediction <- mlflow_predict(model = model, data = input)
  list(prediction = prediction)
}

