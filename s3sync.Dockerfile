# docker build -f s3sync.Dockerfile . -t registryhub/tinyfilemanager-s3sync

# FROM tinyfilemanager/tinyfilemanager
FROM php:cli-alpine

ARG OS_ARCH=Linux-64bit

RUN apk -v --update --no-cache add \
        libzip-dev oniguruma-dev \
        bash inotify-tools \
        dumb-init

RUN docker-php-ext-install \
    zip 

RUN wget -q -c "https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_${OS_ARCH}.tar.gz" -O - | tar -xz -C /usr/local/bin/ && chmod +x /usr/local/bin/s5cmd

ENV S3_PATH S3_ENDPOINT LOCAL_DIR 
ADD s3sync.sh /app/s3sync.sh
RUN chmod a+rx /app/s3sync.sh

WORKDIR /var/www/html
COPY tinyfilemanager.php index.php

RUN sed -i "/'user' => .*/d" "index.php"
RUN sed -i "s/'admin' => .*/'admin' => password_hash(getenv('FILEMANAGER_PASSWORD'), PASSWORD_DEFAULT)/" "index.php"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash", "-c", "php -S 0.0.0.0:$PORT & /app/s3sync.sh upload"]
