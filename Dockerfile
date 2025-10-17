# Użycie lekkiego obrazu Nginx jako bazy
FROM nginx:alpine

# Usunięcie domyślnej strony Nginx
RUN rm -rf /usr/share/nginx/html/*

# Skopiowanie naszej strony do katalogu Nginx
COPY src/index.html /usr/share/nginx/html/index.html

# Domyślny port Nginx (80)
EXPOSE 80
