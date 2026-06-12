# Các câu lệnh chạy spark
## Các câu lệnh chạy 1 script trong python
```spark-submit --master spark://100.127.25.114:7077 test.py```
## Chạy sau khi xong hết các cell trong file notebook --> tránh treo job
```spark.stop()```

## Thêm .gitignore
```# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]

# Environments / Dependencies
.bigdata/
bigdata/
ENV/
__pypackages__/

# IDEs / Editors
.vscode/
.idea/

# Coverage / Logs / Data
.pytest_cache/
.coverage
htmlcov/
*.log

# Project specific
db.sqlite3
.env
```