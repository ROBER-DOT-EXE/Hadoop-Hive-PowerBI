# Guía de Instalación de Hadoop YARN con Hive en Docker (Actualizada)

## 1. Prerrequisitos

### Para Windows:
1. Instalar Docker Desktop
   - Descargar de [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Seguir el asistente de instalación
   - Asegurarse de que WSL 2 está instalado
   - Reiniciar el sistema después de la instalación

### Para cualquier sistema operativo:
1. Verificar que Docker está instalado y funcionando:
```bash
docker --version
docker compose --version
```

## 2. Crear estructura del proyecto

1. Crear un nuevo directorio para el proyecto:
```bash
mkdir hadoop-hive-docker
cd hadoop-hive-docker
```

2. Crear el archivo docker-compose.yml:

```yaml
services:
  namenode:
    container_name: namenode
    image: bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8
    restart: always
    ports:
      - 9870:9870
      - 9000:9000
    volumes:
      - hadoop_namenode:/hadoop/dfs/name
    environment:
      - CLUSTER_NAME=test
    env_file:
      - ./hadoop.env

  datanode:
    container_name: datanode
    image: bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8
    restart: always
    ports:
      - 9864:9864
    volumes:
      - hadoop_datanode:/hadoop/dfs/data
    environment:
      SERVICE_PRECONDITION: "namenode:9870"
    env_file:
      - ./hadoop.env
    depends_on:
      - namenode

  resourcemanager:
    container_name: resourcemanager
    image: bde2020/hadoop-resourcemanager:2.0.0-hadoop3.2.1-java8
    restart: always
    ports:
      - 8088:8088
    environment:
      SERVICE_PRECONDITION: "namenode:9000 namenode:9870 datanode:9864"
    env_file:
      - ./hadoop.env
    depends_on:
      - namenode
      - datanode

  nodemanager:
    container_name: nodemanager
    image: bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8
    restart: always
    ports:
      - 8042:8042
    environment:
      SERVICE_PRECONDITION: "namenode:9000 namenode:9870 datanode:9864 resourcemanager:8088"
    env_file:
      - ./hadoop.env
    depends_on:
      - namenode
      - datanode
      - resourcemanager

  mysql:
    container_name: mysql
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: metastore
      MYSQL_USER: hive
      MYSQL_PASSWORD: hive
    volumes:
      - mysql_data:/var/lib/mysql

  hive-metastore:
    container_name: hive-metastore
    image: apache/hive:4.0.0-alpha-2
    restart: always
    environment:
      DB_DRIVER: mysql
      SERVICE_NAME: metastore
      SERVICE_OPTS: "-Djavax.jdo.option.ConnectionDriverName=com.mysql.jdbc.Driver
                    -Djavax.jdo.option.ConnectionURL=jdbc:mysql://mysql:3306/metastore
                    -Djavax.jdo.option.ConnectionUserName=hive
                    -Djavax.jdo.option.ConnectionPassword=hive"
    ports:
      - "9083:9083"
    depends_on:
      - mysql
      - namenode
      - datanode
    command: /opt/hive/bin/start-metastore

  hive-server2:
    container_name: hive-server2
    image: apache/hive:4.0.0-alpha-2
    restart: always
    environment:
      HIVE_SERVER2_THRIFT_PORT: 10000
      SERVICE_NAME: hiveserver2
    ports:
      - "10000:10000"
      - "10002:10002"
    depends_on:
      - hive-metastore
    command: /opt/hive/bin/start-hiveserver2

volumes:
  hadoop_namenode:
  hadoop_datanode:
  mysql_data:
```

3. Mantener el mismo archivo hadoop.env que en la versión anterior.

## 3. Iniciar el cluster

1. Crear y arrancar todos los servicios:
```bash
docker compose up -d
```

2. Verificar que todos los contenedores están funcionando:
```bash
docker compose ps
```

3. Esperar unos momentos a que todos los servicios estén listos (aproximadamente 1 minuto)

## 4. Caso de uso con Hive

1. Entrar al contenedor de Hive:
```bash
docker compose exec hive-server bash
```

2. Iniciar la consola de Hive:
```bash
beeline -u jdbc:hive2://localhost:10000
```

3. Crear una base de datos y tabla de ejemplo:
```sql
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS retail;
USE retail;

-- Crear tabla de ventas
CREATE TABLE IF NOT EXISTS sales (
    transaction_id INT,
    product_name STRING,
    price DECIMAL(10,2),
    quantity INT,
    purchase_date DATE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;
```

4. Preparar datos de ejemplo (desde el shell del contenedor):
```bash
# Salir de beeline con !quit
echo '1,Laptop,999.99,1,2024-01-01
2,Mouse,24.99,2,2024-01-01
3,Keyboard,59.99,1,2024-01-02
4,Monitor,299.99,1,2024-01-02
5,Laptop,999.99,2,2024-01-03' > /tmp/sales_data.csv

# Crear directorio en HDFS
hdfs dfs -mkdir -p /user/hive/warehouse/retail.db/sales

# Cargar datos
hdfs dfs -put /tmp/sales_data.csv /user/hive/warehouse/retail.db/sales/
```

5. Volver a beeline y ejecutar algunas consultas de ejemplo:
```sql
-- Conectar nuevamente a beeline
beeline -u jdbc:hive2://localhost:10000

-- Usar la base de datos
USE retail;

-- Consultar ventas totales por producto
SELECT 
    product_name,
    COUNT(*) as total_transactions,
    SUM(quantity) as total_units,
    ROUND(SUM(price * quantity), 2) as total_revenue
FROM sales
GROUP BY product_name
ORDER BY total_revenue DESC;

-- Consultar ventas diarias
SELECT 
    purchase_date,
    COUNT(*) as transactions,
    ROUND(SUM(price * quantity), 2) as daily_revenue
FROM sales
GROUP BY purchase_date
ORDER BY purchase_date;

-- Encontrar productos más vendidos
SELECT 
    product_name,
    SUM(quantity) as units_sold
FROM sales
GROUP BY product_name
ORDER BY units_sold DESC
LIMIT 3;
```

## 5. Acceso a las interfaces web

- HDFS NameNode: http://localhost:9870
- YARN ResourceManager: http://localhost:8088
- NodeManager: http://localhost:8042
- Hive Server Web Interface: http://localhost:10002

## 6. Detener el cluster

```bash
docker compose down
```

Para eliminar también los volúmenes:
```bash
docker compose down -v
```

## Solución de problemas comunes

1. Si los contenedores no arrancan correctamente:
```bash
# Ver los logs de todos los servicios
docker compose logs

# Ver logs de servicios específicos
docker compose logs hive-server
docker compose logs hive-metastore
```

2. Si no puedes conectar a Hive:
```bash
# Verificar que el servicio está corriendo
docker compose ps hive-server

# Reiniciar el servicio
docker compose restart hive-server

# Esperar 30 segundos y verificar logs
docker compose logs hive-server
```

3. Si hay problemas con el metastore:
```bash
# Reiniciar los servicios en orden
docker compose restart hive-metastore-postgresql
docker compose restart hive-metastore
docker compose restart hive-server
```

4. Para reiniciar todo el cluster desde cero:
```bash
docker compose down -v
docker compose up -d
```

5. Si hay problemas de permisos en HDFS:
```bash
# Dentro del contenedor namenode
docker compose exec namenode bash
hdfs dfs -chmod -R 777 /user/hive/warehouse
```
