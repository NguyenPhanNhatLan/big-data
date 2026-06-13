from datetime import datetime, timezone

from pyspark import StorageLevel
from pyspark.ml.evaluation import RegressionEvaluator
from pyspark.sql import functions as F


def evaluate_regression(
    predictions,
    label_col="resale_price",
    prediction_col="prediction",
    cache_eval_df=True,
):
    eval_df = (
        predictions.select(
            F.col(label_col).cast("double").alias("label"),
            F.col(prediction_col).cast("double").alias("prediction"),
        )
        .na.drop()
    )

    if cache_eval_df:
        print("[metrics] Caching evaluation dataframe", flush=True)
        eval_df = eval_df.persist(StorageLevel.MEMORY_AND_DISK)

    try:
        print("[metrics] Counting evaluation rows", flush=True)
        count = eval_df.count()
        if count == 0:
            raise ValueError("No valid prediction rows found for metric evaluation.")

        metrics = {}
        for metric_name in ("rmse", "mae", "r2"):
            print(f"[metrics] Computing {metric_name}", flush=True)
            evaluator = RegressionEvaluator(
                labelCol="label",
                predictionCol="prediction",
                metricName=metric_name,
            )
            metrics[metric_name] = float(evaluator.evaluate(eval_df))

        metrics["mse"] = metrics["rmse"] ** 2

        print("[metrics] Computing mape", flush=True)
        mape_row = (
            eval_df.where(F.col("label") != 0)
            .select(
                (
                    F.abs((F.col("label") - F.col("prediction")) / F.col("label"))
                    * 100
                ).alias("ape")
            )
            .agg(F.avg("ape").alias("mape"))
            .first()
        )
        metrics["mape"] = (
            float(mape_row["mape"])
            if mape_row is not None and mape_row["mape"] is not None
            else None
        )
        metrics["count"] = float(count)

        return metrics
    finally:
        if cache_eval_df:
            print("[metrics] Releasing evaluation cache", flush=True)
            eval_df.unpersist()


def print_regression_metrics(model_name, metrics):
    print(f"\n{model_name} metrics")
    print("-" * (len(model_name) + 8))
    for key in ("rmse", "mse", "mae", "r2", "mape", "count"):
        value = metrics.get(key)
        if value is None:
            print(f"{key}: null")
        else:
            print(f"{key}: {value:.6f}")


def save_metrics(spark, metrics, output_path, model_name):
    created_at = datetime.now(timezone.utc)
    run_id = created_at.strftime("%Y%m%dT%H%M%SZ")
    created_at_utc = created_at.isoformat()

    def sql_string(value):
        return "'" + str(value).replace("'", "''") + "'"

    values = []
    for metric, value in metrics.items():
        metric_value = "CAST(NULL AS DOUBLE)" if value is None else str(float(value))
        values.append(
            "("
            f"{sql_string(run_id)}, "
            f"{sql_string(created_at_utc)}, "
            f"{sql_string(model_name)}, "
            f"{sql_string(metric)}, "
            f"{metric_value}"
            ")"
        )

    metrics_df = spark.sql(
        "SELECT * FROM VALUES "
        + ", ".join(values)
        + " AS metrics(run_id, created_at_utc, model, metric, value)"
    )
    print(f"[metrics] Writing metrics to {output_path}", flush=True)
    (
        metrics_df.coalesce(1)
        .write.mode("append")
        .option("header", "true")
        .csv(output_path)
    )

    return run_id
