FROM nginx:1.21.5
COPY ./public /public
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80