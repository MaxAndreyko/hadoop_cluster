# Алгоритма скрипта для разворачивания hadoop
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


# Инициализация open-ssh на контейнерах
! Следующие шаги необходимо повторить для каждого контейнера
1. Открыть командную строку контейнера
```bash
docker exec -it <container_name> bash
```
2. Обновить менеджер пакетов и установить open-ssh
```bash
apt update && apt install openssh-server -y
```
3. Добавить пользователя (user)
```bash
useradd -m user && echo "user:pass" | chpasswd
```
4. Запустить ssh сервис
```bash
service ssh start
```
# Подключение через ssh с другого контейнера
```bash
ssh user@192.168.1.11  # From ubuntu1 to ubuntu2
ssh user@192.168.1.12  # From ubuntu1 to ubuntu3
```
# Создание hadoop кластера
! Необходимо выполнить для каждого сервера

0. Создать не root пользователя
```bash
useradd -m hadoop-user && echo "hadoop-user:<strong password>" | chpasswd
```
1. Установить java
```bash
sudo apt-get install openjdk-11-jdk
```
```bash
java -version
```
2. Скачать дистрибутив hadoop и распаковать
```bash
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz
```
```bash
tar xvzf hadoop-3.4.0.tar.gz
```
3. Установка системных переменных (надо переместить в hadoop-env.sh)
```bash
export HADOOP_HOME=/hadoop-3.4.0 &&
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 &&
export PATH=$PATH:$HADOOP_HOME/bin/:$HADOOP_HOME/sbin &&
export HDFS_NAMENODE_USER="hadoop-user" &&
export HDFS_DATANODE_USER="hadoop-user" &&
export HDFS_SECONDARYNAMENODE_USER="hadoop-user" &&
export YARN_RESOURCEMANAGER_USER="hadoop-user" &&
export YARN_NODEMANAGER_USER="hadoop-user"
```
```bash
hadoop version
```
4. Создать каталог распределенной файловой системы Hadoop (HDFS) для хранения всех соответствующих файлов HDFS
```bash
apt install sudo &&
sudo mkdir -p /usr/local/hadoop/hdfs/data &&
sudo chown -R hadoop-user:hadoop-user /usr/local/hadoop/hdfs/data
```
5. Конфигурация системы
```bash
nano $HADOOP_HOME/etc/hadoop/core-site.xml
```
```html
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```
6. Создание ssh подключения

    1. На мастер ноде генерируем ключ
        ```bash
        ssh-keygen
        ```
        Нажмите клавишу ввода, чтобы использовать значение по умолчанию для местоположения ключа, затем нажмите Enter  дважды, чтобы не использовать парольную фразу.
    2. Копируем сгенерированный публичный ключ
        ```bash
        cat ~/.ssh/id_rsa.pub
        ```
    3. Затем подключитесь к рабочей ноде и откройте файл:
        ```bash
        nano ~/.ssh/authorized_keys
        ```
        Открытый ключ главной ноды, скопированный командой `cat ~/.ssh/id_rsa.pub`, нужно добавить в файл `~/.ssh/authorized_keys` каждой рабочей ноды. Обязательно сохраните файл перед закрытием.
    4. Когда вы закончите обновление рабочих нод, скопируйте открытый ключ главной ноды в свой собственный файл `authorized_keys`:
        ```bash
        nano ~/.ssh/authorized_keys
        ```
    5. На  мастер ноде нужно добавить в конфигурацию ssh имена всех связанных нод. Откройте файл конфигурации для редактирования:
        ```bash
        nano ~/.ssh/config
        ```
        Необходимо вставить следующее:
        ```
        Host 192.168.1.10
        HostName 192.168.1.10
        User hadoop-user
        IdentityFile ~/.ssh/id_rsa
        Host 192.168.1.11
        HostName 192.168.1.11
        User hadoop-user
        IdentityFile ~/.ssh/id_rsa
        Host 192.168.1.12
        HostName 192.168.1.12
        User hadoop-user
        IdentityFile ~/.ssh/id_rsa
        ```
