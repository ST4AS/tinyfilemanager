# docker build -f s3sync.Dockerfile . -t registryhub/tinyfilemanager-s3sync:dev

# FROM tinyfilemanager/tinyfilemanager
FROM php:cli-alpine

ARG OS_ARCH=Linux-64bit

ENV S3SYNC_ENABLE S3SYNC_PATH S3SYNC_LOCAL_DIR AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_BUCKET_NAME S3_ENDPOINT

RUN apk -v --update --no-cache add \
    libzip-dev oniguruma-dev \
    bash inotify-tools \
    dumb-init \
    docker-php-ext-install \
    zip \
    wget -q -c "https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_${OS_ARCH}.tar.gz" -O - | tar -xz -C /usr/local/bin/ && chmod +x /usr/local/bin/s5cmd \
    mkdir -p /var/www/html/data /app

COPY s3sync.sh /app/s3sync.sh
RUN chmod a+rx /app/s3sync.sh

WORKDIR /var/www/html
COPY tinyfilemanager.php index.php

RUN sed -i "/'user' => .*/d" "index.php"
RUN sed -i "s/'admin' => .*/'admin' => password_hash(getenv('FILEMANAGER_PASSWORD'), PASSWORD_DEFAULT)/" "index.php"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash", "-c", "php -S 0.0.0.0:$PORT & /app/s3sync.sh upload"]
