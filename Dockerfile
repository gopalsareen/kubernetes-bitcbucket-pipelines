FROM php:7.2-fpm

ARG commit_hash

RUN mkdir -p /build-code && echo "<?php echo 'Deployed using bitbucket pipelines. $commit_hash' ?>'" > /build-code/index.php

WORKDIR /var/www