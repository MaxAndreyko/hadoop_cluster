#!/bin/bash

# Проверяем, что папка .ssh существует
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

SSH_PUB="$HOME/.ssh/id_rsa.pub"

# Генерируем SSH-ключ без секретной фразы и комментариев в папку ~/.ssh/
echo "Генерация SSH-ключа ..."
ssh-keygen -t rsa -f $SSH_PUB -C "" -N ""

# Добавляем публичный ключ в файл с авторизированными ключами
SSH_AUTH_KEYS="$HOME/.ssh/authorized_keys"
echo "Добавление публичного SSH-ключа к авторизированным ключам ..."
cat $SSH_PUB > $SSH_AUTH_KEYS

# Добавляем данные для подключения к связанным нодам
echo "Конфигурирование SSH подключения к связанным нодам ..."

# Объявляем переменную с путем до конфигурационного файла SSH
SSH_CONFIG="$HOME/.ssh/config"

# Проверяем что конфигурационный файл SSH существует
if [ ! -f "$SSH_CONFIG" ]; then
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
fi

# Функция для добавления нового хоста
add_host() {
    local host_alias="$1" # Имя хоста
    local host_address="$2" # Адрес хоста
    local username="$3" # Имя пользователя для подключения к хосту через SSH
    local identity_file="$HOME/.ssh/id_rsa" # Путь до файла с публичным ключом

    # Проверка, что имя хоста уже существует
    if grep -q "Host $host_alias" "$SSH_CONFIG"; then
        echo "Имя хоста '$host_alias' уже существует в $SSH_CONFIG."
        return 1
    fi

    # Добавление нового хоста в конфигурационный файл
    {
        echo "Host $host_alias"
        echo "    HostName $host_address"
        echo "    User $username"
        echo "    IdentityFile $identity_file"
        echo ""
    } >> "$SSH_CONFIG"

    echo "Добавлен новый хост '$host_alias'."
}

# Цикл для ввода конфигураций хостов
while true; do
    read -p "Введите имя хоста (или 'exit' чтобы выйти): " alias
    if [[ "$alias" == "exit" ]]; then
        break
    fi

    read -p "Введите IP-адрес хоста: " address
    read -p "Введите имя пользователя хоста: " user

    add_host "$alias" "$address" "$user"
done

echo "Конфигурационный файл SSH успешно обновлен."
