FROM nginx:1.27-alpine

RUN apk add --no-cache apache2-utils bash

COPY entrypoint.sh /entrypoint.sh
COPY default.conf.template-only /etc/nginx/default.conf.template-only
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
#CMD ["nginx", "-g", "daemon off;"]
