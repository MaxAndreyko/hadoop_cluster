# Алгоритма скрипта для разворачивания hadoop
! **Перед запуском скрипта необходимо сделать его исполняемым**:
```bash
chmod +x <script-name>.sh
```
## I. Создание подключения по ssh
0. Залогиниться на джамп ноду
1. Добавить hostname для каждой ноды (чтобы обращаться по именам, а не по адресам), убрать localhost, 127.0.0.1
2. Создать пользователя hadoop со сложным паролем
3. Переключиться на пользователя hadoop
4. Создать ssh ключ
5. В цикле спрашиваем ip нод и имя пользователя для подключение. Например, 192.168.1.19, team
6. Заходим на каждую ноду в цикле:
    - Добавить hostname для каждой ноды (чтобы обращаться по именам, а не по адресам), убрать localhost, 127.0.0.1
    - Создание пользователя hadoop-user со сложным паролем
    - Переключиться на пользователя hadoop
    - Создать ssh ключ
7. Вернуться на джамп ноду
8. Создать файл authorized_keys, если нет
9. Добавить в файл authorized_keys созданные на всех нодах ssh ключи с помощью команды `ssh-copy-id team@<node-name>`
10. Скопировать authorized_keys на все ноды с помощью команды `scp ./ssh/authorized_keys team-4-<node-name>:/home/hadoop/.ssh`

## II. Конфигурирование hadoop
0. Поставить sshpass
1. Скачать дистрибутив hadoop на джамп ноду 
2. Скопировать дистрибутив hadoop с джамп ноды на все ноды с помощью команды `scp hadoop-3.4.0.tar.gz team-4-<node-name>:/home/hadoop/hadoop-3.4.0.tar.gz`
3. Распаковать архивы с дистрибутивом hadoop на всех нодах
4. Переключиться на нейм ноду
4. Добавить в ~/.profile системные переменные `JAVA_HOME`, `HADOOP_HOME`, добавить в `PATH` корень исполняемых файлов hadoop `../hadoop/hadoop-3.4.0/sbin`
5. Скопировать файлы `~/.profile` на все ноды
6. Переключаемся в папку `HADOOP_HOME`
7. Добавить `JAVA_HOME` в hadoop-env.sh
8. Скопировать файл hadoop-env.sh на все ноды
9. Добавить в `core-site.xml`:
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://team4-nn:9000</value>
    </property>
</configuration>
```
10. Копируем файл `core-site.xml` на все ноды
11. Добавить в `hdfs-site.xml`:
```xml
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
</configuration>
```
12. Копируем файл `hdf-site.xml` на все ноды
13. Добавить в `workers` адреса всех нод:
```xml
team-4-nn
team-4-dn-00
team-4-dn-01
```
14. Копируем файл `workers` на все ноды
## III. Запуск hadoop кластера
1. Отформатировать файловую систему `bin/hdfs namenode -format`
2. Запустить кластер `sbin/start-dfs.sh`

# Алгоритм разворачивания Hive
## I. Установка Hive
0. Залогиниться на джампноду
1. Войти в пользователя hadoop
2. Скачать дистрибутив hive:
```bash
wget https://dlcdn.apache.org/hive/hive-4.0.1/apache-hive-4.0.1-bin.tar.gz
```
3. Распаковать архив в папку `apache-hive-4.0.1-bin`: `tar -zxvf apache-hive-4.0.1-bin.tar.gz`
4. Добавить переменную среды: `export HIVE_HOME=/home/hadoop/apache-hive-4.0.1-bin`
5. Добавить путь к испольныемым файлам Hive в PATH: `export PATH=/$HIVE_HOME/bin:$PATH`
## II. Конфигурирование Hive
1. Залогиниться на неймноду
2. Войти в пользователя hadoop
3. Создать папку для временных файлов Hive с помощью команды: `hdfs dfs -mkdir /tmp`
4. Создать папку для Hive с помощью команды: `hdfs dfs -mkdir -p /user/hive/warehouse` (можно посмотреть на нее в веб дашборде)
5. Выдать права на папку с временными файлами Hive: `hdfs dfs -chmod g+w /tmp`
6. Выдать права на папку для Hive: `hdfs dfs -chmod g+w /user/hive/warehouse`
7. Инициализировать внутреннюю БД Hive: `$HIVE_HOME/bin/schematool -dbType derby -initSchema`
8. Переключиться на джампноду
9. Войти в пользователя hadoop
10. Скопировать шаблон конфигурационного файла в отдельный файл: `cp $HIVE_HOME/conf/hive-default.xml.template $HIVE_HOME/conf/hive-site.xml`
11. Добавить property, которое будет указывать на папку для хранения данных hive, в `hive-site.xml` (на последней строчке внутри тега `<configuration>`)
```xml
<property>
    <name>hive.metastore.warehouse.dir</name>
    <value>/user/hive/warehouse</value>
    <desciption>Hive warehouse directory</description>
</property>
```
12. Скопировать шаблон `hive-env.sh`: `cp $HIVE_HOME/conf/hive-env.sh.template $HIVE_HOME/conf/hive-env.sh`
13. Добавить в конец `hive-env.sh`:
```xml
export HIVE_HOME=/home/hadoop/apache-hive-4.0.1-bin
export HIVE_CONF_DIR=$HIVE_HOME/conf
export HIVE_AUX_JARS_PATH=$HIVE_HOME/lib/*
```
## III. Запуск Hive
1. Запустить Hive командой:
```bash
hive --hiveconf hive.server2.enable.doAs=false
--hiveconf hive.security.authorization.enabled=false \
--service hiveserver2 1>> /tmp/hs2.log 2>> /tmp/hs2.log
&
```
## IV. Конфигурирование и запуск PostgreSQL
1. Залогиниться на неймноду через team: `ssh team@team-4-nn`
2. Установка PostgreSQL: `sudo apt install postgresql`
3. Залогиниться в пользователя postgres: `sudo -i -u postgres` (нет каталога в домашней папке для этого пользователя, его папка-директория PostgreSQL
4. Подключаемся к консоли postgres: `psql`
5. Создаем базу данных: `CREATE DATABASE metastore`
6. Создаем пользователя базы данных: `CREATE USER hive with password 'ultrahive'`
7. Передаем права пользователю: `GRANT ALL PRIVILEGES ON DATABASE "metastore" TO hive` (этого недостаточно, см.п.8)
8. Сделаем владельцем базы данных созданного пользователя: `ALTER DATABASE OWNER TO hive`
9. Выходим из консоли: `\q`
10. Отключаемся от пользователя: `exit`
11. Даем доступ к базе данных снаружи, правим конфиги:
    1) `sudo nano /etc/postgresql/16/main/postgresql.conf` - параметры подсоединения к базе данных
    2) Раскомментируем строчку и изменим ее, чтобы адрес соответствовал имени нашего хоста ```xml
                                 listen_addresses = 'team-4-nn'
                                 ```
    3) `sudo nano /etc/postgresql/16/main/pg_hba.conf` - параметры доступа к базе данных
    4) Раскомментируем строчку и изменим ее, чтобы адрес соответствовал имени нашего хоста ```xml
                                 #IPv4 local connections:
                                 host  metastore    hive    192.168.1.19/32      password
                                 ```
12. Перезапускаем PostgreSQL: `sudo systemctl restart postgresql`
13. Проверяем: `sudo systemctl status postgresql`
14. Возрващаемся на джампноду 
16. Устанавливаем клиент для PostgreSQL: `sudo apt install postgresql-client-16`
17. Заходим в базу данных: `psql -h team-4-nn -p 5432 -U hive -W metastore`
## V. Конфигурирование и запуск Hive
1. Переключаемся на пользователя hadoop: `sudo -i -u hadoop`
2. Качаем дистрибутив hive: `wget [https//-](https://dlcdn.apache.org/hive/hive-4.0.1/apache-hive-4.0.1-bin.tar.gz)`
3. Распаковывем: `tar -xyzf apache-hive-4.0.1-bin.tar.gz`
4. Перезходим в папку дистрибутива: `cd apache-hive-4.0.1-bin`
5. Качаем драйвер для работы с PostgreSQL: `wget [https//-](https://jdbc.postgresql.org/download/postgresql-42.7.4.jar)`
6. Проверяем наличие драйвера: `ls -l | grep postgres`
7. Правим конфиги:
    1) Переходим в папку с конфигами: `cd ../conf/`
    2) Создаем конфиг: `nano hive-site.xml`
    3) Добавляем в конфиг ```xml
<configuration>
    <property>
        <name>hive.server2.authentication</name>
        <value>NONE</value>
    </property>
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/user/hive/warehouse</value>
    </property>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>5433</value>
        <description>TCP port number to listen on, default 10000</description>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:postgresql://tmpl-nn:5432/metastore</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriver Name</name>
        <value>org.postgresql.Driver</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hive</value>
    </property>
    <property>
        <name> javax.jdo.option.ConnectionPassword</name>
        <value>ultrahive</value>
    </property>
</configuration>
                                 ```
    4) Открываем конфиг hadoop и добавляем в конце: `nano ~/.pro` ```xml
                                 export HIVE_HOME=/home/hadoop/apache-hive.4.0.1-bin
                                 export HIVE_CONF_DIR=$HIVE_HOME/conf
                                 export HIVE_AUX_JARS_PATH=$HIVE_HOME/lib/*
                                 export PATH=$PATH:$HIVE_HOME/bin
                                 ```
    5) Активируем окружение: `source ~/.profile`
8. Убеждаемся, что Hive заработал: `hive --version`
9. Создаем папку: `~/apache-hive-4.0.1-bin/conf$ hdfs dfs -mkdir -p /user/hive/warehouse`
10. Даем права для использования хранилища: `~/apache-hive-4.0.1-bin/conf$ hdfs -chmod g+w /tmp`
11. Даем права для использования хранилища: `~/apache-hive-4.0.1-bin/conf$ hdfs -chmod g+w /user/hive/warehouse`
12. Возвращаемся в директорию: `cd ../`
13. Инициализация схемы базы данных: `bin/schematool -dbType postgres -initSchema`
14. Зпаускаем Hive: `hadoop@tmpl-jn:"/apache-hive-4.0.1-bins hive --hiveconf hive.server2.enable.doAs=false --hiveconf hive.security.authorization.enabled=false --service hiveserver2 1>> /tmp/hs2.log 2>> /tmp/hs2.log &`
                                
