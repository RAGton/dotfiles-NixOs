---
name: data-engineering
description: External project skill — not related to kryonix internals. Use for data platform and analytics work on external projects (ETL/ELT pipelines, dbt, Airflow, Spark, Kafka, DuckDB, ClickHouse, data lakes, data warehouses). Not applicable to kryonix homelab operations.
---

# Engenharia de Dados

## Stack moderna de dados

```
Ingestão      → Airbyte / Fivetran / Kafka / scripts
Armazenamento → S3/MinIO (raw) → DuckDB/ClickHouse (analytics)
Transformação → dbt (SQL) / Spark (big data)
Orquestração  → Airflow / Prefect / Dagster
Visualização  → Superset / Metabase / Grafana
Qualidade     → Great Expectations / dbt tests
```

## dbt — transformação SQL

```yaml
# models/staging/stg_contracts.sql
{{ config(materialized='view') }}

SELECT
    id,
    tenant_id,
    unit_id,
    CAST(start_date AS DATE) AS start_date,
    CAST(end_date AS DATE)   AS end_date,
    monthly_value,
    status,
    created_at
FROM {{ source('raw', 'contracts') }}
WHERE status != 'deleted'
```

```yaml
# models/marts/fct_revenue.sql
{{ config(materialized='table', partition_by={'field': 'month', 'data_type': 'date'}) }}

SELECT
    DATE_TRUNC('month', c.start_date) AS month,
    c.tenant_id,
    COUNT(*)                           AS active_contracts,
    SUM(c.monthly_value)               AS mrr
FROM {{ ref('stg_contracts') }} c
WHERE c.status = 'active'
GROUP BY 1, 2
```

```yaml
# schema.yml — testes automáticos
models:
  - name: stg_contracts
    columns:
      - name: id
        tests: [unique, not_null]
      - name: tenant_id
        tests: [not_null]
      - name: monthly_value
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
```

## DuckDB — analytics local rápido

```python
import duckdb

con = duckdb.connect('analytics.duckdb')

# Lê Parquet direto (S3 ou local)
con.execute("""
    CREATE TABLE IF NOT EXISTS contracts AS
    SELECT * FROM read_parquet('data/contracts/*.parquet')
""")

# Query analítica
result = con.execute("""
    SELECT
        tenant_id,
        DATE_TRUNC('month', start_date) AS month,
        SUM(monthly_value)              AS mrr
    FROM contracts
    WHERE status = 'active'
    GROUP BY 1, 2
    ORDER BY 2 DESC, 3 DESC
""").df()  # retorna pandas DataFrame

# Exportar para Parquet
con.execute("COPY contracts TO 'output/contracts.parquet' (FORMAT PARQUET)")
```

## Apache Spark — big data

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("DataPipeline") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .getOrCreate()

# Leitura
df = spark.read.parquet("s3a://bucket/raw/contracts/")

# Transformação
result = df \
    .filter(F.col("status") == "active") \
    .withColumn("month", F.date_trunc("month", F.col("start_date"))) \
    .groupBy("tenant_id", "month") \
    .agg(F.sum("monthly_value").alias("mrr"),
         F.count("*").alias("count"))

# Escrita Delta Lake (ACID, time travel)
result.write.format("delta").mode("overwrite") \
    .partitionBy("month") \
    .save("s3a://bucket/processed/revenue/")
```

## Airflow — orquestração

```python
from airflow.decorators import dag, task
from airflow.utils.dates import days_ago

@dag(schedule_interval='@daily', start_date=days_ago(1), catchup=False)
def pipeline_contratos():

    @task()
    def extrair():
        # Extrai do banco origem
        return {"rows": 1000}

    @task()
    def transformar(dados: dict):
        # dbt run ou Spark job
        return {"processed": dados["rows"]}

    @task()
    def carregar(dados: dict):
        # Carrega no DW
        print(f"Carregados: {dados['processed']}")

    dados = extrair()
    transformados = transformar(dados)
    carregar(transformados)

dag = pipeline_contratos()
```

## Kafka — streaming

```python
from confluent_kafka import Producer, Consumer

# Produtor
producer = Producer({'bootstrap.servers': 'localhost:9092'})
producer.produce('contracts', key='123', value='{"event": "created", ...}')
producer.flush()

# Consumidor
consumer = Consumer({
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'pipeline-group',
    'auto.offset.reset': 'earliest'
})
consumer.subscribe(['contracts'])

while True:
    msg = consumer.poll(1.0)
    if msg and not msg.error():
        print(f"Evento: {msg.value().decode()}")
```

## Modelagem dimensional

```sql
-- Fato: evento mensurável
CREATE TABLE fct_pagamentos (
    pagamento_id  BIGINT PRIMARY KEY,
    data_id       INT REFERENCES dim_data(data_id),
    tenant_id     INT REFERENCES dim_tenant(tenant_id),
    contrato_id   BIGINT,
    valor         DECIMAL(12,2),
    status        VARCHAR(20)
);

-- Dimensão: contexto descritivo
CREATE TABLE dim_data (
    data_id       INT PRIMARY KEY,
    data          DATE,
    ano           INT,
    mes           INT,
    trimestre     INT,
    dia_semana    VARCHAR(15)
);
```

## Qualidade de dados — Great Expectations

```python
import great_expectations as gx

context = gx.get_context()
validator = context.sources.pandas_default.read_parquet("contracts.parquet")

# Defina expectativas
validator.expect_column_values_to_not_be_null("tenant_id")
validator.expect_column_values_to_be_between("monthly_value", min_value=0)
validator.expect_column_values_to_be_unique("id")

results = validator.validate()
if not results.success:
    raise ValueError("Qualidade de dados falhou — pipeline abortado")
```

## Referências adicionais
- **ClickHouse**: ver [references/clickhouse.md](references/clickhouse.md)
- **Delta Lake / Iceberg**: ver [references/lakehouse.md](references/lakehouse.md)
- **Prefect / Dagster**: ver [references/orchestration.md](references/orchestration.md)
