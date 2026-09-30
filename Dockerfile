# syntax=docker/dockerfile:1
#
# Imagem do frontend em dois estágios:
#   1. build: compila o app Flutter para web (precisa do SDK, ~2 GB)
#   2. final: só o nginx + os arquivos gerados (~50 MB)
# O SDK fica no estágio de build e não vai para a imagem final.

FROM debian:trixie-slim AS build

# SDK oficial do Flutter (versão fixa, a mesma do CI).
ARG FLUTTER_VERSION=3.47.2
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
       | tar -xJ -C /opt \
    && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --no-analytics --no-cli-animations \
    && flutter precache --web

WORKDIR /app

# Dependências primeiro: esta camada só é refeita quando o pubspec muda.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN dart run build_runner build

# API_BASE_URL relativa: o nginx atende app e API na mesma origem.
ARG API_BASE_URL=/api
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Cache-busting (issue #5): hash do código e dos assets vira o prefixo v/<hash>/
# de onde o flutter_bootstrap.js carrega o app (ver web/flutter_bootstrap.js).
RUN version=$(find build/web/main.dart.js build/web/assets -type f -print0 \
        | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-12) \
    && sed -i "s/__BUILD_VERSION__/${version}/" build/web/flutter_bootstrap.js \
    && grep -q "v/\${buildVersion}/" build/web/flutter_bootstrap.js \
    && grep -q "'${version}'" build/web/flutter_bootstrap.js \
    && echo "build version: ${version}"


FROM nginx:1.29-alpine AS final

# Templates em /etc/nginx/templates passam por envsubst na inicialização
# (${BACKEND_URL} vira o valor da variável de ambiente).
COPY deploy/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

ENV BACKEND_URL=http://host.docker.internal:8080
EXPOSE 80
