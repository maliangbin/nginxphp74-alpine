# 预编译PHP扩展阶段
FROM php:7.4-fpm-alpine AS build
RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories
# PHP 扩展编译
RUN set -xe \
    && apk add --no-cache openssl-dev freetype-dev libjpeg-turbo-dev libpng-dev libxml2-dev libwebp-dev gettext-dev argon2-dev libxml2-dev libxslt-dev zlib-dev imagemagick-dev libzip-dev \
    && docker-php-ext-configure gd  \
    && docker-php-ext-install gd zip bcmath pdo_mysql calendar exif gettext mysqli pcntl shmop sockets sysvmsg sysvsem sysvshm xsl\
    && apk add --no-cache autoconf ${PHPIZE_DEPS}
RUN set -xe \
    && pecl install https://pecl.php.net/get/redis-5.3.4.tgz \
    && pecl install https://pecl.php.net/get/mongodb-1.11.1.tgz \
    && pecl install https://pecl.php.net/get/swoole-4.8.9.tgz \
    && pecl install https://pecl.php.net/get/xlswriter-1.5.1.tgz \
    && pecl install https://pecl.php.net/get/xhprof-2.3.5.tgz \
    && pecl install https://pecl.php.net/get/imagick-3.6.0.tgz 


# 正式阶段
FROM php:7.4-fpm-alpine
LABEL maintainer="maliangbin"

# 替换国内系统镜像源
RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories
# 安装依赖包
RUN set -xe \
    && apk add --no-cache \
    nginx \  
    supervisor \
    openssl \
    freetype \
    libjpeg-turbo \
    libpng \
    libxml2 \
    libwebp \
    gettext \
    argon2 \
    libxml2 \
    libxslt \
    libstdc++ \
    zlib \
    imagemagick \
    libzip \
    git
# COPY build 阶段编译的 PHP 扩展
COPY --from=build /usr/local/lib/php/extensions/no-debug-non-zts-20190902/ /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
COPY --from=build /usr/local/include/php/ext/swoole/ /usr/local/include/php/ext/swoole/
COPY --from=build /usr/local/include/php/ext/imagick/ /usr/local/include/php/ext/imagick/

# 启用 PHP 扩展
RUN set -xe \
    && docker-php-ext-enable gd zip bcmath pdo_mysql calendar exif gettext mysqli pcntl shmop sockets sysvmsg sysvsem sysvshm xsl opcache redis mongodb swoole xlswriter xhprof imagick

RUN set -ex \
    # - config PHP
    && { \
    echo "swoole.use_shortname='Off'"; \
    } | tee /usr/local/etc/php/conf.d/99_overrides.ini

# 安装 composer
RUN set -xe \
    && curl -o /usr/local/bin/composer -fSL "https://mirrors.aliyun.com/composer/composer.phar" \
    && chmod +x /usr/local/bin/composer \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

WORKDIR /var/www/html

COPY ./php.ini /usr/local/etc/php/php.ini
COPY ./php-fpm.d/ /usr/local/etc/php-fpm.d/
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/conf.d/*.conf /etc/nginx/conf.d/
COPY ./supervisor/supervisord.conf /etc/supervisord.conf
COPY ./supervisor/conf.d/*.ini /etc/supervisor.d/

# 清理
RUN set -xe \
    && docker-php-source delete

# 暴露端口
EXPOSE 80 9000 9501

ENTRYPOINT []
# 启动Supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]

