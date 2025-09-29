library(mlflow)

# Set tracking URI if needed
mlflow_set_tracking_uri("http://127.0.0.1:5000")

# Load the registered model (version 3)
model_uri <- "models:/random-forest/1"
model <- mlflow_load_model(model_uri)

input <- data.frame(
  crim = 0.1,
  zn = 0,
  indus = 8.14,
  chas = 0,
  nox = 0.5,
  rm = 6.0,
  age = 65,
  dis = 4.0,
  rad = 4,
  tax = 307,
  ptratio = 18,
  black = 390,
  lstat = 12
)

prediction <- mlflow_predict(model = model, data = input)
print(prediction)