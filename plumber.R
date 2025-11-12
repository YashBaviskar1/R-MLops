# plumber.R
library(plumber)
library(mlflow)
library(jsonlite)

# ---------------------------------------------
# CONFIGURATION
# ---------------------------------------------

# Read environment variables (these will be passed by Seldon)
mlflow_uri <- Sys.getenv("MLFLOW_TRACKING_URI", unset = "http://172.26.95.101:5000")
s3_endpoint <- Sys.getenv("MLFLOW_S3_ENDPOINT_URL", unset = "http://172.26.95.101:8001")
aws_key <- Sys.getenv("AWS_ACCESS_KEY_ID", unset = "admin")
aws_secret <- Sys.getenv("AWS_SECRET_ACCESS_KEY", unset = "admin123")

# Set up MLflow + MinIO connection
mlflow_set_tracking_uri(mlflow_uri)
Sys.setenv(
  AWS_ACCESS_KEY_ID = aws_key,
  AWS_SECRET_ACCESS_KEY = aws_secret,
  MLFLOW_S3_ENDPOINT_URL = s3_endpoint
)

# Set your model path (from MLflow run or S3)
# Example: "runs:/79be2b3c0fc443fdb23b06824d576a79/model"
# or "s3://mlflow-artifacts/7/79be2b3c0fc443fdb23b06824d576a79/artifacts/model"
model_uri <- Sys.getenv(
  "MODEL_URI",
  unset = "s3://mlflow-artifacts/7/79be2b3c0fc443fdb23b06824d576a79/artifacts/model"
)

cat("🚀 Starting R model microservice...\n")
cat("🔗 MLflow tracking URI:", mlflow_uri, "\n")
cat("🔗 S3 endpoint:", s3_endpoint, "\n")
cat("📦 Loading model from:", model_uri, "\n")

# Load model
model <- mlflow_load_model(model_uri)
cat("✅ Model loaded successfully\n")

# ---------------------------------------------
# API ROUTES
# ---------------------------------------------

#* @apiTitle Iris rpart Model API (Seldon-Compatible)
#* @apiDescription Predicts iris species from input features.

#* Health check endpoint
#* @get /health
function() {
  list(status = "OK", message = "R model microservice is healthy.")
}

#* Predict endpoint for Seldon Core
#* @post /predict
#* @serializer unboxedJSON
function(req, res) {
  tryCatch({
    # Parse JSON payload (Seldon sends it as {"data":{"ndarray":[...]}})
    body <- fromJSON(req$postBody)
    input <- as.data.frame(body$data$ndarray)
    names(input) <- c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")

    # Predict
    preds <- mlflow_predict(model, input)

    # Format response as Seldon expects
    list(
      data = list(
        names = list("prediction"),
        ndarray = as.list(as.character(preds))
      )
    )
  }, error = function(e) {
    res$status <- 500
    list(error = e$message)
  })
}
