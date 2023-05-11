# docker build -f s3sync.Dockerfile . -t registryhub/tinyfilemanager-s3sync

# FROM tinyfilemanager/tinyfilemanager
FROM php:cli-alpine3.15

RUN apk -v --update --no-cache add \
        libzip-dev oniguruma-dev \
        python3 py3-pip py3-magic py3-six \
        groff \
        less \
        mailcap \
        bash inotify-tools \
        dumb-init

RUN pip3 install --ignore-installed --upgrade awscli==1.14.5 s3cmd==2.0.1 python-magic six
# RUN apk -v --purge del py3-pip
# RUN rm -f /var/cache/apk/*

RUN docker-php-ext-install \
    zip 

ENV S3_PATH S3_ENDPOINT LOCAL_DIR 
ADD s3sync.sh /app/s3sync.sh
RUN chmod a+rx /app/s3sync.sh

WORKDIR /var/www/html
COPY tinyfilemanager.php index.php

RUN sed -i "/'user' => .*/d" "index.php"
RUN sed -i "s/'admin' => .*/'admin' => password_hash(getenv('FILEMANAGER_PASSWORD'), PASSWORD_DEFAULT)/" "index.php"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash", "-c", "php -S 0.0.0.0:$PORT & /app/s3sync.sh upload"]
