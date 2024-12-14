# Алгоритм запуска скриптов ПЗ №1-3
> [!IMPORTANT]
> - Перед началом работы необходимо склонировать репозиторий со скриптами на джампноде командой:  
> `git clone https://github.com/MaxAndreyko/hadoop_cluster.git`;
> - Если во время выполнения скриптов появится запрос на ввод пароля от `sudo`/`team` в терминале, укажите его.

## ПЗ №1 - Hadoop
### I. Подготовка к запуску скриптов
Переходим в папку со скриптами `hadoop_cluster/scripts/task1` к ПЗ №1 и делаем их исполняемыми:
```bash
cd ~/hadoop_cluster/scripts/task1 && chmod +x ./*.sh
```
### II. Создание подключения по SSH
1. Для создания подключения по ssh запускаем скрипт `create_users.sh`. В консоли необходимо ввести пароль от `sudo`/`team`, так как скрипт запускается с root правами:
```bash
sudo ./create_users.sh
```
2. Далее необходимо ввести имя (например, `hadoop`) и пароль для создания нового пользователя. Запомните пароль к созданному пользовател, он потребуется далее;
3. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматического создания подключения по SSH."`.
### III. Разворачивание Hadoop
1. Для разворачивания hadoop запускаем скрипт `hadoop_setup.sh`:
```bash
sudo ./hadoop_setup.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh), и пароль к нему. После ввода ожидаем завершение выполенния скрипта;
3. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматического разворачивания hadoop."`.

## ПЗ №2 - Веб-интерфейсы
### I. Подготовка к запуску скриптов
Переходим в папку со скриптами `hadoop_cluster/scripts/task2` к ПЗ №2 и делаем их исполняемыми:
```bash
cd ~/hadoop_cluster/scripts/task2 && chmod +x ./*.sh
```
### II. Настройка и запуск веб-интерфейсов (ResourceManager, NodeManager, History Server, веб-сервер Nginx)
> [!IMPORTANT]
> - Во время выполнения скрипта появится запрос в терминале на ввод имени пользователя и пароля для доступа к веб-интерфейсу.
> - Придумайте имя пользователя и пароль. Запомните эти данные, чтобы в дальнейшем авторизироваться в веб-интерфейсе. 
1. Для запуска веб-интерфейсов запускаем скрипт `web_setup.sh`:
```bash
sudo ./web_setup.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [ПЗ№1, п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh), и пароль к нему. После ввода ожидаем завершение выполенния скрипта;
4. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматической настройки и запуска веб-интерфейсов."`.
> [!NOTE]
> После успешного выполнения скрипта появится возможность воспользоваться веб-интерфейсами, которые доступны по адресами (при прокидывании портов через конфигурационный файл ssh, см. [инструкцию](https://github.com/MaxAndreyko/hadoop_cluster/blob/main/README.md#прокидывание-портов-через-ssh)):
> - Hadoop Cluster: 
> ```
> http://localhost:9870
> ```
> - YARN:
> ```
> http://localhost:8088
> ```
> - History Server:
> ```
> http://localhost:19888
> ```
> ### Прокидывание портов через ssh
> В файл конфигурации подключения через ssh необходимо добавить `LocalForward <port>  127.0.0.1:<port>`, где <port> - порт, который необходимо "прокинуть".
>  Например:
> ```
> Host <host>
> HostName <hostname>
> User team
>   IdentityFile <path to identity file>
>   LocalForward 9870  127.0.0.1:9870
>   LocalForward 8088  127.0.0.1:8088
>   LocalForward 19888  127.0.0.1:19888
> ```

## ПЗ №3 - Hive + PostgreSQL
### I. Подготовка к запуску скриптов
Переходим в папку со скриптами `hadoop_cluster/scripts/task3` к ПЗ №3 и делаем их исполняемыми:
```bash
cd ~/hadoop_cluster/scripts/task3 && chmod +x ./*.sh
```
### II. Установка Hive
1. Для установки hive по ssh запускаем скрипт `hive_setup.sh`:
```bash
sudo ./hive_setup.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [ПЗ№1, п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh).
3. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматической установки hive."`.
### III. Настройка metastore
1. Для настройки metastore PostgreSQL запускаем скрипт `metastore_setup.sh`:
```bash
sudo ./metastore_setup.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [ПЗ№1, п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh).
3. Далее необходимо ввести имя пользователя для доступа к базе метаданных (например, `hive`) и пароль к нему.
4. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматической настройки metastore."`.
### IV. Загрузка и трансформация данных
1. Для загрузки и обработки данных запускаем скрипт `transform_data.sh`:
```bash
sudo ./transform_data.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [ПЗ№1, п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh).
3. Далее необходимо ввести имя пользователя, созданного в п.1, и пароль к нему. Послее ввода ожидаем завершение выполенния скрипта;
4. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматической загрузки и трансформации данных."`.

## ПЗ №4 - Spark
### I. Подготовка к запуску скриптов
Переходим в папку со скриптами `hadoop_cluster/scripts/task4` к ПЗ №4 и делаем их исполняемыми:
```bash
cd ~/hadoop_cluster/scripts/task4 && chmod +x ./*.sh
```
### II. Установка Spark и работа с данными
1. Для установки spark запускаем скрипт `spark_setup.sh`:
```bash
sudo ./spark_setup.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [ПЗ№1, п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh).
3. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматической установки spark и получение результирующего набора данных."`.

## ПЗ №5 - Обработка данных под управлением Prefect
### I. Подготовка к запуску скриптов
Переходим в папку со скриптами `hadoop_cluster/scripts/task5` к ПЗ №5 и делаем их исполняемыми:
```bash
cd ~/hadoop_cluster/scripts/task5 && chmod +x ./*.sh
```
### II. Установка Prefect и обработка данных
1. Для установки spark запускаем скрипт `prefect.sh`:
```bash
sudo ./prefect.sh
```
2. Далее необходимо ввести имя пользователя, созданного в [ПЗ№1, п.2](https://github.com/MaxAndreyko/hadoop_cluster/tree/main?tab=readme-ov-file#ii-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BF%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%BF%D0%BE-ssh).
3. При успешном выполнении всех команд скрипта в терминале должно отобразиться `"Завершение автоматической установки prefect и получение результирующего набора данных под его управлением."`.

