# --- Load libraries ---
if (!require("mlflow", quietly = TRUE)) install.packages("mlflow")
if (!require("carrier", quietly = TRUE)) install.packages("carrier")
if (!require("randomForest", quietly = TRUE)) install.packages("randomForest")
if (!require("MASS", quietly = TRUE)) install.packages("MASS")

library(mlflow)
library(carrier)
library(randomForest)
library(MASS)

# --- Set MLflow connection ---
mlflow_set_tracking_uri("http://localhost:5000")
mlflow_set_experiment("boston-randomforest")

# --- Load dataset ---
data("Boston")

# --- Split data ---
set.seed(123)
train_idx <- sample(1:nrow(Boston), 0.8 * nrow(Boston))
train <- Boston[train_idx, ]
test <- Boston[-train_idx, ]

# --- Train model ---
model_rf <- randomForest(medv ~ ., data = train)

# --- Evaluate ---
preds <- predict(model_rf, newdata = test)
mse <- mean((preds - test$medv)^2)
r2 <- 1 - sum((preds - test$medv)^2) / sum((test$medv - mean(test$medv))^2)

# --- Log to MLflow ---
mlflow_start_run()
print("✅ MLflow run started...")

mlflow_log_param("model_type", "random_forest")
mlflow_log_metric("mse", mse)
mlflow_log_metric("r_squared", r2)

# --- Define Crate (explicit namespace reference) ---
rf_crate <- crate(
  function(newdata) {
    randomForest:::predict.randomForest(model, newdata = newdata)
  },
  model = model_rf
)

# --- Save model with R flavor ---
model_path <- "rf_model_crate"
mlflow_save_model(
  rf_crate,
  path = model_path,
  flavor = mlflow_rfunc()
)

mlflow_log_artifact(model_path, artifact_path = "model")

print(paste("✅ Model logged successfully with MSE =", round(mse, 4)))

mlflow_end_run()
