# 1: Ввод данных

# Ввод IP-адреса сервера
read -p "Введите IP-адрес сервера: " SERVER_IP

# Ввод имени пользователя
read -p "Введите имя пользователя: " USER_NAME

echo -e "\e[32m>>>>>>>>>>>>>>>> Начало настройки системы для сервера $SERVER_IP с пользователем $USER_NAME. <<<<<<<<<<<<<<<\e[0m"

# 2: Настройка сервера

#Установка sudo
echo -e "\e[32m>>>>>>>>>>>>>>>> Устанавливаем sudo... <<<<<<<<<<<<<<<\e[0m"
apt-get install -y sudo

# Обновление Ubuntu
echo -e "\e[32m>>>>>>>>>>>>>>>> Обновляем пакеты системы... <<<<<<<<<<<<<<<\e[0m"
sudo apt-get update && sudo apt-get -y dist-upgrade

# Установка Java
echo -e "\e[32m>>>>>>>>>>>>>>>> Устанавливаем OpenJDK 8... <<<<<<<<<<<<<<<\e[0m"
sudo apt-get -y install openjdk-8-jdk-headless

# Создание каталога для установки Hadoop
echo -e "\e[32m>>>>>>>>>>>>>>>> Создаем директорию для установки Hadoop... <<<<<<<<<<<<<<<\e[0m"
mkdir ~/my-hadoop-install

#Переход в папку для установки Hadoop
echo -e "\e[32m>>>>>>>>>>>>>>>> Переходим в директорию для установки Hadoop... <<<<<<<<<<<<<<<\e[0m"
cd ~/my-hadoop-install

# Скачивание и установка Hadoop 3.0.1
echo -e "\e[32m>>>>>>>>>>>>>>>> Скачиваем Hadoop 3.4.0... <<<<<<<<<<<<<<<\e[0m"
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz

echo -e "\e[32m>>>>>>>>>>>>>>>> Извлекаем содержимое Hadoop... <<<<<<<<<<<<<<<\e[0m"
tar xvzf hadoop-3.4.0.tar.gz

# 3: Настройка среды Hadoop

# Настройка JAVA_HOME в hadoop-env.sh
echo -e "\e[32m>>>>>>>>>>>>>>>> Конфигурируем JAVA_HOME... <<<<<<<<<<<<<<<\e[0m"
sed -i '/export JAVA_HOME=/c\export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/hadoop-env.sh

# Добавление переменных среды для запуска Hadoop
echo -e "\e[32m>>>>>>>>>>>>>>>> Конфигурируем переменные среды для запуска Hadoop... <<<<<<<<<<<<<<<\e[0m"
echo "
export HDFS_NAMENODE_USER=\"$USER_NAME\"
export HDFS_DATANODE_USER=\"$USER_NAME\"
export HDFS_SECONDARYNAMENODE_USER=\"$USER_NAME\"
export YARN_RESOURCEMANAGER_USER=\"$USER_NAME\"
export YARN_NODEMANAGER_USER=\"$USER_NAME\"" >> ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/hadoop-env.sh

# Применение изменений
echo -e "\e[32m>>>>>>>>>>>>>>>> Применяем изменения... <<<<<<<<<<<<<<<\e[0m"
source ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/hadoop-env.sh

# Создание каталога HDFS
echo -e "\e[32m>>>>>>>>>>>>>>>> Создаем HDFS директорию... <<<<<<<<<<<<<<<\e[0m"
sudo mkdir -p /usr/local/hadoop/hdfs/data

# Передача прав текущему пользователю
echo -e "\e[32m>>>>>>>>>>>>>>>> Устанавливаем права доступа на директорию HDFS для $USER_NAME... <<<<<<<<<<<<<<<\e[0m"
sudo chown -R $USER_NAME:$USER_NAME /usr/local/hadoop/hdfs/data

# 4: Завершение начальной настройки

# Настройка core-site.xml
echo -e "\e[32m>>>>>>>>>>>>>>>> Конфигурируем core-site.xml... <<<<<<<<<<<<<<<\e[0m"
cat <<EOL > ~/my-hadoop-install/hadoop-3.4.0/etc/hadoop/core-site.xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$SERVER_IP:9000</value>
    </property>
</configuration>
EOL

echo -e "\e[32m>>>>>>>>>>>>>>>> Завершение настройки системы. <<<<<<<<<<<<<<<\e[0m"