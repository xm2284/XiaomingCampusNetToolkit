FROM python:3.11-slim

WORKDIR /app

# 先装依赖（利用构建缓存）
COPY requirements.txt .
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple \
        -r requirements.txt

COPY app.py .

ENV DB_PATH=/data/stats.db \
    PORT=8080 \
    CHART_CACHE_SEC=300

VOLUME ["/data"]
EXPOSE 8080

# waitress 生产级 WSGI 服务器，4 线程足够统计小流量
CMD ["waitress-serve", "--host=0.0.0.0", "--port=8080", "--threads=4", "app:app"]
