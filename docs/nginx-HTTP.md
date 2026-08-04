[Voltar](../README.md)
# Nginx HTTP

```bash
server {
	listen 80;
	listen [::]:80;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html index.php;

	server_name seudominio.com.br;

	location = /favicon.ico { access_log off; log_not_found off; }
  
	location / {
		proxy_pass http://localhost:3000;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection 'upgrade';
		proxy_set_header Host $host;
		proxy_cache_bypass $http_upgrade;
	}

	# deny access to .htaccess files, if Apache's document root
	# concurs with nginx's one
	#
	location ~ /\.ht {
		deny all;
	}

	location ~ /\. {
		access_log off;
		log_not_found off;
		deny all;
	}

	gzip on;
	gzip_disable "msie6";

	gzip_comp_level 6;
	gzip_min_length 1100;
	gzip_buffers 4 32k;
	gzip_proxied any;
	gzip_types
		text/plain
		text/css
		text/js
		text/xml
		text/javascript
		application/javascript
		application/x-javascript
		application/json
		application/xml
		application/rss+xml
		image/svg+xml;

	access_log off;
	#access_log  /var/log/nginx/seudominio.com.br-access.log;
	error_log   /var/log/nginx/seudominio.com.br-error.log;

	#include /etc/nginx/common/protect.conf;
}

```

