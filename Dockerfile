#
# SECURELYSHARE CONFIDENTIAL
# __________________
#
# [2013] - [2018] SecurelyShare Software Private Limited.
# All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains
# the property of SecurelyShare Software Private Limited
# and its suppliers, if any. The intellectual and technical
# concepts contained herein are proprietary to SecurelyShare
# Software Private Limited and its suppliers and may be
# covered by U.S. and Foreign Patents, patents in process,
# and are protected by trade secret or copyright law.
# Dissemination of this information or reproduction of this
# material is strictly forbidden unless prior written permission
# is obtained from SecurelyShare Software Private Limited.
#

FROM alpine:3.10.1

LABEL maintainer=shivakumarkr1@gmail.com

# 82 is the standard uid/gid for "www-data" in Alpine
# https://git.alpinelinux.org/cgit/aports/tree/main/apache2/apache2.pre-install?h=v3.8.1
# https://git.alpinelinux.org/cgit/aports/tree/main/lighttpd/lighttpd.pre-install?h=v3.8.1
# https://git.alpinelinux.org/cgit/aports/tree/main/nginx/nginx.pre-install?h=v3.8.1

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH

ARG HTTPD_VERSION=2.4.39
ARG HTTPD_SHA256=b4ca9d05773aa59b54d66cd8f4744b945289f084d3be17d7981d1783a5decfa2

# https://httpd.apache.org/security/vulnerabilities_24.html
ENV HTTPD_PATCHES=""

RUN set -eux \
    ; addgroup -g 82 -S www-data \
    ; adduser -u 82 -D -S -G www-data www-data \
    ; HTTPD_VERSION=2.4.39 \
    ; HTTPD_SHA256=b4ca9d05773aa59b54d66cd8f4744b945289f084d3be17d7981d1783a5decfa2 \
    ; mkdir -p "$HTTPD_PREFIX" \
    ; cd "$HTTPD_PREFIX" \
    ; chown www-data:www-data "$HTTPD_PREFIX" \
    ; runDeps=' \
          apr-dev \
          apr-util-dev \
          apr-util-ldap \
          perl \
          jansson \
          hiredis \
          pcre \
        ' \
    ; apk update \
    ; apk add --no-cache --virtual .build-deps \
        $runDeps \
        ca-certificates \
        coreutils \
        dpkg-dev dpkg \
        gcc \
        gnupg \
        libc-dev \
        curl-dev \
        jansson-dev \
        libxml2-dev \
        lua-dev \
        make \
        nghttp2-dev \
        openssl \
        openssl-dev \
        pcre-dev \
        tar \
        wget \
        pkgconfig \
        hiredis-dev \
        automake \
        autoconf \
        libtool \
        zlib-dev \
        ;\
        ddist() { \
            local f="$1"; shift; \
            local distFile="$1"; shift; \
            local success=; \
            local distUrl=; \
            for distUrl in \
              'https://www.apache.org/dyn/closer.cgi?action=download&filename=' \
              https://www-us.apache.org/dist/ \
              https://www.apache.org/dist/ \
              https://archive.apache.org/dist/ \
            ; do \
              if wget -nv --show-progress --progress=bar:force:noscroll -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
                success=1; \
                break; \
              fi; \
            done; \
            [ -n "$success" ]; \
          } \
      ; ddist 'httpd.tar.bz2' "httpd/httpd-$HTTPD_VERSION.tar.bz2" \
      ; echo "$HTTPD_SHA256 *httpd.tar.bz2" | sha256sum -c - \
      ; ddist 'httpd.tar.bz2.asc' "httpd/httpd-$HTTPD_VERSION.tar.bz2.asc" \
      ; export GNUPGHOME="$(mktemp -d)" \
      ; for key in \
      # gpg: key 791485A8: public key "Jim Jagielski (Release Signing Key) <jim@apache.org>" imported
          A93D62ECC3C8EA12DB220EC934EA76E6791485A8 \
      # gpg: key 995E35221AD84DFF: public key "Daniel Ruggeri (https://home.apache.org/~druggeri/) <druggeri@apache.org>" imported
          B9E8213AEFB861AF35A41F2C995E35221AD84DFF \
        ; do \
          gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
        done; \
        gpg --batch --verify httpd.tar.bz2.asc httpd.tar.bz2; \
        command -v gpgconf && gpgconf --kill all || :; \
        rm -rf "$GNUPGHOME" httpd.tar.bz2.asc \
      ; mkdir -p src \
      ; tar -xf httpd.tar.bz2 -C src --strip-components=1 \
      ; rm httpd.tar.bz2 \
      ; cd src \
      ; \
        patches() { \
          while [ "$#" -gt 0 ]; do \
            local patchFile="$1"; shift; \
            local patchSha256="$1"; shift; \
            ddist "$patchFile" "httpd/patches/apply_to_$HTTPD_VERSION/$patchFile"; \
            echo "$patchSha256 *$patchFile" | sha256sum -c -; \
            patch -p0 < "$patchFile"; \
            rm -f "$patchFile"; \
          done; \
        }; \
        patches $HTTPD_PATCHES; \
        gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
      ; ./configure \
        --build="$gnuArch" \
        --prefix="$HTTPD_PREFIX" \
        --enable-mods-shared=reallyall \
        --enable-mpms-shared=all \
      ; make -j "$(nproc)"\
      ; make install \
      ; cd .. \
      ; rm -r src man manual \
      ; sed -ri \
          -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
          -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
          -e 's!^(\s*TransferLog)\s+\S+!\1 /proc/self/fd/1!g' \
          "$HTTPD_PREFIX/conf/httpd.conf" \
          "$HTTPD_PREFIX/conf/extra/httpd-ssl.conf" \
      ; runDeps="$runDeps $( \
          scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
        )" \
      ; httpd -v \
# Build cjose
    ; CJOSE_VERSION=0.6.1 \
    ; mkdir -p src \
    ; wget -nv --show-progress --progress=bar:force:noscroll -O cjose.tar.gz \
      https://github.com/cisco/cjose/archive/${CJOSE_VERSION}.tar.gz \
    ; tar -xzf cjose.tar.gz -C src --strip-components 1 \
    ; cd src \
    ; ./configure \
    ; make \
    ; make install \
    ; cd .. \
    ; rm -r src cjose.tar.gz \
# build openidc plugin
    ; OPENIDC_VERSION=2.3.11 \
    ; mkdir -p src \
    ; wget -nv --show-progress --progress=bar:force:noscroll -O openidc.tar.gz \
        https://github.com/zmartzone/mod_auth_openidc/archive/v${OPENIDC_VERSION}.tar.gz \
    ; tar -xzf openidc.tar.gz -C src --strip-components 1 \
    ; cd src \
    ; ./autogen.sh \
    ; APR_CFLAGS="${HTTPD_PREFIX}/include" \
    ; APR_LIBS="${HTTPD_PREFIX}/lib" \
    ; ./configure --with-apxs2="${HTTPD_PREFIX}/bin/apxs" \
    ; make \
    ; make install \
    ; cd .. \
    ; rm -r openidc.tar.gz src \
    ; echo >> 'LoadModule auth_openidc_module modules/mod_auth_openidc.so' >> "${HTTPD_PREFIX}/conf/httpd.conf" \
    ; apk add --virtual .httpd-rundeps $runDeps \
    ; apk del .build-deps

COPY httpd-foreground /usr/local/bin/

EXPOSE 80

CMD ["httpd-foreground"]