from pyspark.ml.regression import LinearRegression

from common import LABEL_COL, run_training


def main():
    def build_lr():
        return LinearRegression(
            featuresCol="features",
            labelCol=LABEL_COL,
            predictionCol="prediction",
            maxIter=100,
            regParam=0.05,
            elasticNetParam=0.0,
        )

    run_training(
        model_name="Linear Regression",
        model_subdir="lr",
        build_regressor=build_lr,
        scale_features=True,
    )


if __name__ == "__main__":
    main()
