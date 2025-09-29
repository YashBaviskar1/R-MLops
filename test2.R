library(mlflow)

# 1. Set the tracking server URI
mlflow_set_tracking_uri("http://127.0.0.1:5000")

# 2. Define which registered model you want to deploy
model_name <- "random-forest"
model_version <- "1"

# 3. Get the model version details from the registry
model_version_details <- mlflow_get_model_version(
  name = model_name,
  version = model_version
)

# 4. Extract the physical source URI
# This is the path you need for Seldon Core!
physical_uri <- model_version_details$source

# The output will be the direct path in MinIO
# e.g., "s3://mlflow-artifacts/d2cbc5aedb1b43d79da1f989b437028c/artifacts/rf_model"
print(paste("Physical URI for Seldon Core:", physical_uri))