# plumber.R
library(plumber)
library(mlflow)

# -------------------------------
# CONFIGURATION
# -------------------------------
mlflow_set_tracking_uri("http://172.26.95.101:5000")

Sys.setenv(
  AWS_ACCESS_KEY_ID = "admin",
  AWS_SECRET_ACCESS_KEY = "admin123",
  MLFLOW_S3_ENDPOINT_URL = "http://127.0.0.1:8001"
)

model_URI <- "s3://mlflow-artifacts/7/79be2b3c0fc443fdb23b06824d576a79/artifacts/model"
cat("Loading model from:", model_URI, "\n")
model <- mlflow_load_model(model_URI)
cat("✅ Model loaded successfully\n")

# -------------------------------
# API ROUTES
# -------------------------------

#* @apiTitle Iris rpart model serving API
#* @apiDescription Predicts species from iris flower features.

#* Health check
#* @get /health
function() {
  list(status = "OK", message = "Plumber MLflow model API running")
}

#* Predict endpoint
#* @post /predict
#* @param Sepal.Length Sepal length in cm
#* @param Sepal.Width Sepal width in cm
#* @param Petal.Length Petal length in cm
#* @param Petal.Width Petal width in cm
#* @json
function(req, res, Sepal.Length, Sepal.Width, Petal.Length, Petal.Width) {
  # Convert inputs to numeric dataframe
  input <- data.frame(
    Sepal.Length = as.numeric(Sepal.Length),
    Sepal.Width = as.numeric(Sepal.Width),
    Petal.Length = as.numeric(Petal.Length),
    Petal.Width = as.numeric(Petal.Width)
  )

  # Predict
  prediction <- mlflow_predict(model, input)
  list(prediction = as.character(prediction))
}
