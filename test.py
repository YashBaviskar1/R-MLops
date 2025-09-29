import mlflow

mlflow.set_tracking_uri("http://127.0.0.1:5000")  # or wherever your mlflow server is running

print(mlflow.search_registered_models())