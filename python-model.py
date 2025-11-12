import mlflow
import mlflow.sklearn
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
import pandas as pd
import numpy as np
np.random.seed(42)
X = np.random.rand(100, 1) * 10    
y = 2.5 * X.squeeze() + np.random.randn(100) * 2  #
data = pd.DataFrame({"X": X.squeeze(), "y": y})
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
mlflow.set_tracking_uri("http://127.0.0.1:5000/")
mlflow.set_experiment("simple-linear-regression1")
with mlflow.start_run():
    model = LinearRegression()
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    mse = mean_squared_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    mlflow.log_param("fit_intercept", model.fit_intercept)
    mlflow.log_metric("mse", mse)
    mlflow.log_metric("r2", r2)
    mlflow.sklearn.log_model(model, "model")
    data.to_csv("data.csv", index=False)
    mlflow.log_artifact("data.csv")
    print(f"Model logged in MLflow with MSE: {mse:.2f}, R2: {r2:.2f}")
