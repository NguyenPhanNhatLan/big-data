from pyspark.ml.regression import GBTRegressor

from common import LABEL_COL, run_training


def main():
    def build_gbt():
        return GBTRegressor(
            featuresCol="features",
            labelCol=LABEL_COL,
            predictionCol="prediction",
            maxIter=100,
            maxDepth=5,
            stepSize=0.1,
            seed=42,
        )

    run_training(
        model_name="Gradient-Boosted Tree",
        model_subdir="gbt_v2",
        build_regressor=build_gbt,
    )


if __name__ == "__main__":
    main()
