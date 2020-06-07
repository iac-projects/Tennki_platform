FROM nginx:1.18-alpine
COPY app/* /app/
COPY conf /etc/nginx/conf.d/default.conf
EXPOSE 8000
CMD ["nginx","-g","daemon off;"]