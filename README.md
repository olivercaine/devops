# Devops

Assorted code for deployment and hosting.

Test NGINX image with:

```
docker run -it -p 80:80 \
    -v /$PWD/dist/://usr/share/nginx/html:ro \
    -v /$PWD/devops/nginx/nginx.conf://etc/nginx/nginx.conf:ro \
    nginx:alpine
```