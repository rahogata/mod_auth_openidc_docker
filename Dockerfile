FROM httpd:2.4.39-alpine

LABEL maintainer=shivakumarkr1@gmail.com

RUN set -eux \
    ; runDeps=' \
          jansson \
          hiredis \
          pcre \
        ' \
    ; apk update \
    ; apk add --no-cache --virtual .build-deps \
        $runDeps \
        ca-certificates \
        gcc \
        libc-dev \
        curl-dev \
        jansson-dev \
        libxml2-dev \
        make \
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
    ; echo 'LoadModule auth_openidc_module modules/mod_auth_openidc.so' >> "${HTTPD_PREFIX}/conf/httpd.conf" \
    ; apk add --virtual .openidc-rundeps $runDeps \
    ; apk del .build-deps
