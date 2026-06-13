from pyspark.ml.regression import RandomForestRegressor

from common import LABEL_COL, run_training


def main():
    def build_rf():
        return RandomForestRegressor(
            featuresCol="features",
            labelCol=LABEL_COL,
            predictionCol="prediction",
            numTrees=100,
            maxDepth=10,
            seed=42,
        )

    run_training(
        model_name="Random Forest",
        model_subdir="rf",
        build_regressor=build_rf,
    )


if __name__ == "__main__":
    main()
