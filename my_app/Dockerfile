# Dockerfile
FROM nginx:1.23.1

# Копи статические файлы
COPY static /usr/share/nginx/html/static
COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Копи кастомный конфиг
# COPY nginx.conf /etc/nginx/conf.d/default.conf
# Открываем порт 80
EXPOSE 80