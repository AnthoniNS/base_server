# base_server

sudo mkdir ./conf/traefik/.certificates

sudo chmod -R 777 base_server

## Novo app deve ser inserido as labe

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
      - traefik.http.routers.portainer.entryPoints=web-secure // <- routers."portainer", portainer é o nome do servico! mude colocando nome do novo servico
      - traefik.http.routers.portainer.rule=Host(`portainer.comandas.io`)
      - traefik.http.routers.portainer.tls=true
      - traefik.http.services.portainer.loadBalancer.server.port=9000
      - traefik.http.routers.portainer.tls.certResolver=lets-encrypt
    environment:
      - TZ=America/Sao_Paulo
    networks:
      - minharede
      
// a networks sempre tem que colocar      
networks:
  minharede:
    external: true
