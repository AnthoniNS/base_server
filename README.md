# Base Server

Este repositório contém a configuração para um servidor base utilizando Docker e Traefik.

## Configuração Inicial

Crie a pasta de certificados:
```bash
sudo mkdir -p ./conf/traefik/.certificates
```

Defina as permissões adequadas:
```bash
sudo chmod -R 777 base_server
```

## Adicionando um Novo Aplicativo

Sempre que um novo serviço for adicionado, ele deve conter as labels do Traefik configuradas corretamente.

Exemplo de configuração para um serviço Docker:

```yaml
version: '3.9'

services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    labels:
      - traefik.enable=true
      - traefik.http.routers.portainer.entryPoints=web-secure # "portainer" é o nome do serviço. Mude para o nome do novo serviço.
      - traefik.http.routers.portainer.rule=Host(`portainer.comandas.io`)
      - traefik.http.routers.portainer.tls=true
      - traefik.http.services.portainer.loadBalancer.server.port=9000
      - traefik.http.routers.portainer.tls.certResolver=lets-encrypt
    environment:
      - TZ=America/Sao_Paulo
    networks:
      - minharede
```

## Configuração de Redes

A rede `minharede` é utilizada para garantir que todos os serviços dentro do Docker possam se comunicar corretamente. Como essa rede é externa, ela permite que diferentes `docker-compose.yml` compartilhem os mesmos serviços sem precisar recriar redes separadas para cada aplicação. Isso facilita a gestão e conexão entre contêineres.

```yaml
networks:
  minharede:
    external: true
```

