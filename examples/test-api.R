# -------------------------------------
# Boston Housing Price Prediction API
# Using MLflow + MinIO + Plumber (Seldon-Compatible)
# -------------------------------------

library(plumber)
library(mlflow)
library(jsonlite)

# ---------------------------------------------
# CONFIGURATION
# ---------------------------------------------

# Read environment variables (will be injected by Docker/Seldon)
mlflow_uri   <- Sys.getenv("MLFLOW_TRACKING_URI", unset = "http://172.26.95.101:5000")
s3_endpoint  <- Sys.getenv("MLFLOW_S3_ENDPOINT_URL", unset = "http://172.26.95.101:8001")
aws_key      <- Sys.getenv("AWS_ACCESS_KEY_ID", unset = "admin")
aws_secret   <- Sys.getenv("AWS_SECRET_ACCESS_KEY", unset = "admin123")
model_uri    <- Sys.getenv("MODEL_URI", unset = "s3://mlflow-artifacts/9/6ee2a932beb84a3b875694a36af388a1/artifacts/model")

cat("🚀 Starting R model microservice...\n")
cat("🔗 MLflow tracking URI:", mlflow_uri, "\n")
cat("🔗 S3 endpoint:", s3_endpoint, "\n")
cat("📦 Loading model from:", model_uri, "\n")

# Set MLflow + MinIO connections
mlflow_set_tracking_uri(mlflow_uri)
Sys.setenv(
  AWS_ACCESS_KEY_ID = aws_key,
  AWS_SECRET_ACCESS_KEY = aws_secret,
  MLFLOW_S3_ENDPOINT_URL = s3_endpoint
)

# Load model
model <- mlflow_load_model(model_uri)
cat("✅ Model loaded successfully\n")

# ---------------------------------------------
# API ROUTES
# ---------------------------------------------

#* @apiTitle Boston Housing MLflow Model API
#* @apiDescription Predicts house price (`medv`) using Boston dataset features.

#* Health check endpoint
#* @get /health
function() {
  list(status = "OK", message = "Boston Housing MLflow microservice healthy 🚀")
}

#* Prediction endpoint (Seldon-compatible)
#* @post /predict
#* @serializer unboxedJSON
function(req, res) {
  tryCatch({
    # Parse JSON payload: {"data": {"ndarray": [[...]]}}
    body <- fromJSON(req$postBody)
    input <- as.data.frame(body$data$ndarray)
    names(input) <- c(
      "crim", "zn", "indus", "chas", "nox", "rm", "age", "dis",
      "rad", "tax", "ptratio", "black", "lstat"
    )

    # Predict
    preds <- mlflow_predict(model, input)

    # Return in Seldon-compatible structure
    list(
      data = list(
        names = list("predicted_medv"),
        ndarray = list(round(as.numeric(preds), 3))
      ),
      units = "thousands of dollars"
    )
  }, error = function(e) {
    res$status <- 500
    list(error = e$message)
  })
}
