# syntax=docker/dockerfile:1
#
# Static Flutter-web build served by nginx. No Flutter toolchain needed at
# build time — this repo already contains the compiled output.

# ---- stage 1: precompress everything worth compressing ----------------------
FROM alpine:3.20 AS compress
WORKDIR /site
COPY . .
RUN apk add --no-cache gzip \
 && rm -f nginx.conf \
 && find . -type f \
      \( -name '*.js'   -o -name '*.mjs'  -o -name '*.json' \
      -o -name '*.css'  -o -name '*.html' -o -name '*.wasm' \
      -o -name '*.ttf'  -o -name '*.otf'  -o -name '*.svg'  \
      -o -name '*.bin'  -o -name 'NOTICES' \) \
      -size +1k \
      -exec gzip -9 -k -f {} \;

# ---- stage 2: runtime -------------------------------------------------------
FROM nginx:1.27-alpine

RUN rm -rf /usr/share/nginx/html/*
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=compress /site /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
