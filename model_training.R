# 1. Load libraries
# The script will try to install them if you don't have them
if (!require("rpart", quietly = TRUE)) install.packages("rpart")
if (!require("mlflow", quietly = TRUE)) install.packages("mlflow")

library(rpart)
library(mlflow)

# 2. Set MLflow tracking URI and experiment
# This MUST match the server you just started
mlflow_set_tracking_uri("http://localhost:5000")
mlflow_set_experiment("iris-rpart")

# 3. Start an MLflow run
# All metrics, params, and the model will be logged under this run
mlflow_start_run()
print("--- MLflow run started ---")

# Ensure the run always ends, even if an error occurs
tryCatch({
    
    # 4. Load and prepare data
    data(iris)
    print("--- Iris Data Head ---")
    print(head(iris))
    set.seed(123)

    train_indices <- sample(1:nrow(iris), 0.7 * nrow(iris))
    train_data <- iris[train_indices, ]
    test_data <- iris[-train_indices, ]

    # 5. Train model
    print("--- Training rpart model ---")
    model <- rpart(Species ~ ., data = train_data, method = "class")

    # 6. Make predictions and evaluate
    predictions <- predict(model, test_data, type = "class")

    print("--- Confusion Matrix ---")
    conf_matrix <- table(Predicted = predictions, Actual = test_data$Species)
    print(conf_matrix)

    accuracy <- mean(predictions == test_data$Species)
    print(paste("Accuracy:", round(accuracy * 100, 2), "%"))

    # 7. Log parameters to MLflow
    print("--- Logging parameters ---")
    mlflow_log_param("model_type", "rpart")
    mlflow_log_param("train_size", nrow(train_data))
    mlflow_log_param("test_size", nrow(test_data))
    mlflow_log_param("seed", 123)

    # 8. Log metric to MLflow
    print("--- Logging metric ---")
    mlflow_log_metric("accuracy", accuracy)

    # 9. Log the model to MLflow (Explicit Crate Method)
    print("--- Saving model using 'crate' flavor locally ---")

    # Load required package for crate
    if (!require("carrier", quietly = TRUE)) install.packages("carrier")
    library(carrier)

    # Define a custom prediction wrapper for the rpart model
    rpart_model_crate <- carrier::crate(
    function(newdata) {
        rpart:::predict.rpart(model, newdata, type = "class")
    },
    model = model
    )



    # Define model path
    model_path <- "my_rpart_model_crate"

    # Save the model using MLflow crate flavor
    mlflow_save_model(
    rpart_model_crate,
    path = model_path,
    flavor = mlflow_rfunc()  # ensures R function flavor for serving
    )

    print(paste("Crated files saved to:", model_path))

    # Log this directory as an artifact in MLflow
    print("--- Logging the 'crated' model directory as an artifact ---")
    mlflow_log_artifact(model_path, artifact_path = "model")
    print("--- Model successfully logged ---")

    # Clean up the local directory
    unlink(model_path, recursive = TRUE)

}, error = function(e) {
    # Print and log any errors
    message("An error occurred: ", e$message)
    mlflow_log_param("run_status", "FAILED")
    mlflow_log_param("error_message", e$message)
}, finally = {
    # 10. End the MLflow run
    mlflow_end_run()
    print("--- MLflow run finished ---")
})