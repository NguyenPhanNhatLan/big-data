import argparse
import os
import sys
from pathlib import Path

from pyspark.ml import Pipeline
from pyspark.ml.feature import OneHotEncoder, StandardScaler, StringIndexer, VectorAssembler
from pyspark.sql import SparkSession
from pyspark.sql import functions as F


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from metrics import evaluate_regression, print_regression_metrics, save_metrics


LABEL_COL = "resale_price"
CATEGORICAL_COLS = ["town", "flat_type", "flat_model"]
NUMERIC_COLS = [
    "floor_area_sqm",
    "lease_commence_date",
    "transaction_year",
    "transaction_month",
    "remaining_lease_months",
    "flat_age",
    "storey_avg",
]

DEFAULT_HDFS_ROOT = os.getenv("HDFS_ROOT", "hdfs://100.127.25.114:9000")
DEFAULT_DATA_ROOT = os.getenv("DATA_ROOT", f"{DEFAULT_HDFS_ROOT}/data-src")
DEFAULT_TRAIN_PATH = os.getenv("TRAIN_PATH")
DEFAULT_TEST_PATH = os.getenv("TEST_PATH", "")
DEFAULT_MODEL_ROOT = os.getenv(
    "MODEL_ROOT",
    os.getenv("MODEL_DIR", f"{DEFAULT_HDFS_ROOT}/model"),
)
DEFAULT_METRICS_PATH = os.getenv("METRICS_PATH")


def log_step(message):
    print(f"[train] {message}", flush=True)


def set_handle_invalid_keep(stage):
    if hasattr(stage, "setHandleInvalid"):
        return stage.setHandleInvalid("keep")
    return stage


def parse_args(model_subdir):
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", default=DEFAULT_DATA_ROOT)
    parser.add_argument("--train-path", default=DEFAULT_TRAIN_PATH)
    parser.add_argument("--test-path", default=DEFAULT_TEST_PATH)
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--model-path", default=None)
    parser.add_argument("--metrics-path", default=None)
    parser.add_argument("--master", default=os.getenv("SPARK_MASTER", None))
    parser.add_argument("--no-save-metrics", action="store_true")
    args = parser.parse_args()

    model_root = args.model_root.rstrip("/")
    if args.model_path is None:
        args.model_path = f"{model_root}/{model_subdir}"
    if args.metrics_path is None:
        args.metrics_path = f"{model_root}/metrics"
    if args.train_path is None:
        args.train_path = f"{args.data_root.rstrip('/')}/train_csv"

    return args


def build_spark(app_name, master=None):
    builder = SparkSession.builder.appName(app_name)
    if master:
        builder = builder.master(master)
    return builder.getOrCreate()


def load_dataset(spark, path):
    df = (
        spark.read.option("header", "true")
        .option("inferSchema", "true")
        .csv(path)
    )

    required_cols = CATEGORICAL_COLS + NUMERIC_COLS + [LABEL_COL]
    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        raise ValueError(f"Missing required columns: {missing_cols}")

    for col_name in NUMERIC_COLS + [LABEL_COL]:
        df = df.withColumn(col_name, F.col(col_name).cast("double"))

    return df.select(required_cols).na.drop()


def build_training_pipeline(regressor, scale_features=False):
    index_cols = [f"{col}_idx" for col in CATEGORICAL_COLS]
    encoded_cols = [f"{col}_ohe" for col in CATEGORICAL_COLS]

    indexers = [
        set_handle_invalid_keep(StringIndexer(inputCol=col, outputCol=index_col))
        for col, index_col in zip(CATEGORICAL_COLS, index_cols)
    ]
    encoder = set_handle_invalid_keep(
        OneHotEncoder(inputCols=index_cols, outputCols=encoded_cols)
    )

    assembler_output = "features_raw" if scale_features else "features"
    assembler = set_handle_invalid_keep(
        VectorAssembler(
            inputCols=NUMERIC_COLS + encoded_cols,
            outputCol=assembler_output,
        )
    )

    stages = [*indexers, encoder, assembler]
    if scale_features:
        stages.append(
            StandardScaler(
                inputCol="features_raw",
                outputCol="features",
                withMean=False,
                withStd=True,
            )
        )
    stages.append(regressor)

    return Pipeline(stages=stages)


def run_training(model_name, model_subdir, build_regressor, scale_features=False):
    args = parse_args(model_subdir)
    log_step(f"Starting {model_name}")
    log_step(f"train_path={args.train_path}")
    log_step(f"test_path={args.test_path or '(using train data)'}")
    log_step(f"model_path={args.model_path}")
    log_step(f"metrics_path={args.metrics_path}")

    spark = build_spark(f"Train {model_name}", args.master)

    try:
        log_step("Building estimator")
        regressor = build_regressor()
        log_step("Loading train data")
        train_df = load_dataset(spark, args.train_path)
        log_step("Building pipeline")
        pipeline = build_training_pipeline(regressor, scale_features=scale_features)
        log_step("Fitting model")
        model = pipeline.fit(train_df)
        log_step("Saving model")
        model.write().overwrite().save(args.model_path)
        log_step("MODEL SAVED SUCCESSFULLY")

        log_step("Loading evaluation data")
        eval_df = load_dataset(spark, args.test_path) if args.test_path else train_df
        log_step("Transforming evaluation data")
        predictions = model.transform(eval_df)
        log_step("Evaluating predictions")
        metrics = evaluate_regression(predictions, label_col=LABEL_COL)
        print_regression_metrics(model_name, metrics)

        metrics_run_id = None
        if not args.no_save_metrics:
            log_step("Saving metrics")
            metrics_run_id = save_metrics(spark, metrics, args.metrics_path, model_name)
            log_step("METRICS SAVED SUCCESSFULLY")

        print(f"\nSaved model to: {args.model_path}")
        if not args.no_save_metrics:
            print(f"Saved metrics to: {args.metrics_path}")
            print(f"Metrics run_id: {metrics_run_id}")
    finally:
        spark.stop()
