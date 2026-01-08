#!/usr/bin/env sh

docker build -t docker-gen-pihole .
docker tag docker-gen-with-cli garrettheath4/docker-gen-with-cli:latest
docker push --all-tags garrettheath4/docker-gen-with-cli
