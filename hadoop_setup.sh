# 1: Ввод данных

# Ввод IP-адреса сервера
read -p "Введите IP-адрес сервера: " SERVER_IP

# Ввод имени пользователя
read -p "Введите имя пользователя: " USER_NAME

echo "Начало настройки системы для сервера $SERVER_IP с пользователем $USER_NAME."

# 2: Настройка сервера

#Установка sudo
echo "Устанавливаем sudo..."
apt-get install -y sudo

# Обновление Ubuntu
echo "Обновляем пакеты системы..."
sudo apt-get update && sudo apt-get -y dist-upgrade

# Установка Java
echo "Устанавливаем OpenJDK 8..."
sudo apt-get -y install openjdk-8-jdk-headless

# Создание каталога для установки Hadoop
echo "Создаем директорию для установки Hadoop..."
mkdir ~/my-hadoop-install && cd ~/my-hadoop-install

# Скачивание и установка Hadoop 3.0.1
echo "Скачиваем Hadoop 3.4.0..."
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz

echo "Извлекаем содержимое Hadoop..."
tar xvzf hadoop-3.4.0.tar.gz

# 3: Настройка среды Hadoop

# Настройка JAVA_HOME в hadoop-env.sh
echo "Конфигурируем JAVA_HOME..."
sed -i '/export JAVA_HOME=/c\export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/hadoop-env.sh

# Добавление переменных среды для запуска Hadoop
echo "Конфигурируем переменные среды для запуска Hadoop..."
echo "
export HDFS_NAMENODE_USER=\"$USER_NAME\"
export HDFS_DATANODE_USER=\"$USER_NAME\"
export HDFS_SECONDARYNAMENODE_USER=\"$USER_NAME\"
export YARN_RESOURCEMANAGER_USER=\"$USER_NAME\"
export YARN_NODEMANAGER_USER=\"$USER_NAME\"" >> ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/hadoop-env.sh

# Применение изменений
echo "Применяем изменения..."
source ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/hadoop-env.sh

# Создание каталога HDFS
echo "Создаем HDFS директорию..."
sudo mkdir -p /usr/local/hadoop/hdfs/data

# Передача прав текущему пользователю
echo "Устанавливаем права доступа на директорию HDFS для $USER_NAME..."
sudo chown -R $USER_NAME:$USER_NAME /usr/local/hadoop/hdfs/data

# 4: Завершение начальной настройки

# Настройка core-site.xml
echo "Конфигурируем core-site.xml..."
cat <<EOL > ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/core-site.xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$SERVER_IP:9000</value>
    </property>
</configuration>
EOL

echo "Завершение настройки системы."
