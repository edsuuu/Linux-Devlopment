[Voltar](../README.md)

# Docker & Docker composer

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
```bash
sudo systemctl start docker 
```
```bash
sudo usermod -aG docker $USER
```

# Database && Apps
```bash
mkdir -p "$HOME/database" && cd "$HOME/database" && curl -fsSL "https://raw.githubusercontent.com/edsuuu/Linux-Devlopment/refs/heads/main/docs/docker-compose.yml" -o "$HOME/database/docker-compose.yml" && sudo docker compose -f "$HOME/database/docker-compose.yml" up -d
```

- Para criar um DB dentro do container
```bash
docker exec -it nomeDoContainer bash
```
```bash
psql -U postgres

mysql -U root
```
```bash
create database nome; \q
```

- Para importar um dump 
```bash
docker exec -i postgres_container psql -U postgres -d nomeDobanco < dump.sql

docker exec -i mysql_container mysql -U root -d nomeDobanco < dump.sql
```
- Para fazer um dump do banco atual
```bash
docker exec -t postgres_container pg_dump -U postgres -d banco_atual > dump.sql

docker exec -t mysql_container mysql_dump -U postgres -d banco_atual > dump.sql
```

# Comandos
- Parar Todos os Containers
```bash
docker stop $(docker ps -aq)
```
- Remover Todos os Containers
```bash
docker rm $(docker ps -aq)
```
- Remover Todas as Imagens
```bash
docker rmi $(docker images -q)
```
- Remover Todos os Volumes
```bash
docker volume rm $(docker volume ls -q)
```
- Docker remover tudo junto
```bash
docker stop $(docker ps -aq) && docker rm $(docker ps -aq) && docker rmi $(docker images -q) && docker volume rm $(docker volume ls -q)
```
