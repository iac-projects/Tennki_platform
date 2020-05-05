FROM nginx:1.18-alpine
RUN apk add --no-cache shadow 
RUN usermod -u 1001 -o nginx && groupmod -g 1001 -o nginx && apk del shadow
COPY app/* /app/
COPY conf /etc/nginx/conf.d/default.conf
EXPOSE 8000
CMD ["nginx","-g","daemon off;"]