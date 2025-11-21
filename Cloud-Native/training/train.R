library(rpart)
library(mlflow)
library(carrier)

# --- CONFIGURATION ---
# We force the S3 settings that we KNOW work from your debug job
Sys.setenv(AWS_S3_ENDPOINT = "minio-service:9000")
Sys.setenv(AWS_S3_PATH_STYLE_ACCESS = "true")
Sys.setenv(AWS_DEFAULT_REGION = "")

tracking_uri <- Sys.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
print(paste("Connecting to MLflow at:", tracking_uri))

mlflow_set_tracking_uri(tracking_uri)
mlflow_set_experiment("iris-rpart")

print("--- MLflow run started ---")
with(mlflow_start_run(), {
    
    # 1. Prepare Data
    data(iris)
    set.seed(123)
    train_indices <- sample(1:nrow(iris), 0.7 * nrow(iris))
    train_data <- iris[train_indices, ]
    test_data <- iris[-train_indices, ]

    # 2. Train
    print("--- Training model ---")
    model <- rpart(Species ~ ., data = train_data, method = "class")

    # 3. Metrics
    predictions <- predict(model, test_data, type = "class")
    accuracy <- mean(predictions == test_data$Species)
    
    mlflow_log_param("model_type", "rpart")
    mlflow_log_metric("accuracy", accuracy)

    # 4. Log Model (The Fix!)
    # We use 'crate' to package the function + model dependencies
    predictor <- crate(function(x) rpart:::predict.rpart(model, x, type = "class"), model = model)
    
    # CHANGED: mlflow_save_model (Local) -> mlflow_log_model (Remote Upload)
    print("--- Uploading model to MinIO... ---")
    mlflow_log_model(predictor, artifact_path = "model", flavor = mlflow_rfunc())
    print("--- Upload successful ---")

    # 5. The Handoff
    run <- mlflow_get_run()
    # Construct the S3 URI where MLflow put it
    full_model_uri <- paste0(run$artifact_uri, "/model")
    
    print(paste("Model URI:", full_model_uri))

    # Write URI to shared volume
    writeLines(full_model_uri, "/pipeline-data/latest_model_uri.txt")
})
