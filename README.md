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
