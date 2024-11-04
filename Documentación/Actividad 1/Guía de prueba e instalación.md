# Ver los resultados finales
1. Abrir en una terminal la carpeta con el docker

2. Arrancar todos los servicios:
```bash
docker compose up -d
```

3. Entrar al contenedor namenode:
```bash
docker compose exec namenode bash
```

4. Ver el conteo de las palabras:
```bash
hdfs dfs -cat /user/root/wordcount/output/part-r-00000
```

# Guía para crear todo desde 0

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
mkdir hadoop-yarn-docker
cd hadoop-yarn-docker
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

volumes:
  hadoop_namenode:
  hadoop_datanode:
```

3. Crear el archivo de variables de entorno hadoop.env:
```bash
CORE_CONF_fs_defaultFS=hdfs://namenode:9000
CORE_CONF_hadoop_http_staticuser_user=root
CORE_CONF_hadoop_proxyuser_hue_hosts=*
CORE_CONF_hadoop_proxyuser_hue_groups=*
CORE_CONF_io_compression_codecs=org.apache.hadoop.io.compress.SnappyCodec

HDFS_CONF_dfs_webhdfs_enabled=true
HDFS_CONF_dfs_permissions_enabled=false
HDFS_CONF_dfs_namenode_datanode_registration_ip___hostname___check=false

YARN_CONF_yarn_log___aggregation___enable=true
YARN_CONF_yarn_log_server_url=http://historyserver:8188/applicationhistory/logs/
YARN_CONF_yarn_resourcemanager_recovery_enabled=true
YARN_CONF_yarn_resourcemanager_store_class=org.apache.hadoop.yarn.server.resourcemanager.recovery.FileSystemRMStateStore
YARN_CONF_yarn_resourcemanager_scheduler_class=org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler
YARN_CONF_yarn_scheduler_capacity_root_default_maximum___allocation___mb=8192
YARN_CONF_yarn_scheduler_capacity_root_default_maximum___allocation___vcores=4
YARN_CONF_yarn_resourcemanager_fs_state___store_uri=/rmstate
YARN_CONF_yarn_resourcemanager_system___metrics___publisher_enabled=true
YARN_CONF_yarn_resourcemanager_hostname=resourcemanager
YARN_CONF_yarn_resourcemanager_address=resourcemanager:8032
YARN_CONF_yarn_resourcemanager_scheduler_address=resourcemanager:8030
YARN_CONF_yarn_resourcemanager_resource__tracker_address=resourcemanager:8031
YARN_CONF_yarn_timeline___service_enabled=true
YARN_CONF_yarn_timeline___service_generic___application___history_enabled=true
YARN_CONF_yarn_nodemanager_remote___app___log___dir=/app-logs
```

## 3. Iniciar el cluster

1. Crear y arrancar todos los servicios:
```bash
docker compose up -d
```

2. Verificar que todos los contenedores están funcionando:
```bash
docker compose ps
```

3. Esperar unos momentos a que todos los servicios estén listos (aproximadamente 30 segundos)

## 4. Prueba del cluster

1. Entrar al contenedor namenode:
```bash
docker compose exec namenode bash
```

2. Crear un directorio de prueba en HDFS:
```bash
hdfs dfs -mkdir -p /user/root/test
```

3. Crear un archivo de prueba:
```bash
echo "Hola Mundo desde Hadoop YARN en Docker" > test.txt
hdfs dfs -put test.txt /user/root/test
```

4. Verificar que el archivo está en HDFS:
```bash
hdfs dfs -cat /user/root/test/test.txt
```

## 5. Ejemplo WordCount

1. Dentro del contenedor namenode:
```bash
# Crear directorio para input
hdfs dfs -mkdir -p /user/root/wordcount/input

# Crear archivo de prueba
echo "Hola mundo Hadoop YARN mundo" > input.txt
hdfs dfs -put input.txt /user/root/wordcount/input

# Ejecutar WordCount
hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar wordcount /user/root/wordcount/input /user/root/wordcount/output

# Ver resultados
hdfs dfs -cat /user/root/wordcount/output/part-r-00000
```

## 6. Acceso a las interfaces web

- HDFS NameNode: http://localhost:9870
- YARN ResourceManager: http://localhost:8088
- NodeManager: http://localhost:8042

## 7. Detener el cluster

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

# Ver logs de un servicio específico
docker compose logs namenode
docker compose logs resourcemanager
```

2. Si no puedes acceder al namenode:
```bash
# Reiniciar el contenedor
docker compose restart namenode

# Verificar que está corriendo
docker compose ps namenode
```

3. Para reiniciar todo el cluster desde cero:
```bash
docker compose down -v
docker compose up -d
```

4. Si hay problemas de permisos en Windows:
   - Asegurarse de que Docker Desktop tiene acceso a la carpeta del proyecto
   - Ejecutar Docker Desktop como administrador

5. Si los servicios tardan en estar disponibles:
   - Esperar aproximadamente 30 segundos después del `docker compose up -d`
   - Verificar el estado con `docker compose ps`
   - Revisar los logs para ver el progreso del inicio