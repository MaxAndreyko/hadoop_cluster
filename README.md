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