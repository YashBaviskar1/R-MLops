run_id = "27b820f454c546088423ae89dd06bcd8"

import mlflow
mlflow.set_tracking_uri("http://127.0.0.1:5000/")
# Replace this with your run_id
model_uri = f"runs:/{run_id}/model"
print("Model URI:", model_uri)
