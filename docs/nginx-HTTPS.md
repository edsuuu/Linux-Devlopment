[Voltar](../README.md)
# Nginx HTTPS
```bash

server {
  listen 80 default_server;
  server_name _;
  return 404;
}

# Redireciona para HTTPS
server {
	listen 80;
	listen [::]:80;
  server_name seudominio.com.br;
  return 301 https://$host$request_uri;
}

# HTTPS
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name seudominio.com.br;

	# O servidor só vai responder pra este domínio
  if ($host != "seudominio.com.br") {
    return 404;
  }
	
	ssl_certificate /etc/letsencrypt/live/seudominio.com.br/fullchain.pem; # managed by Certbot
	ssl_certificate_key /etc/letsencrypt/live/seudominio.com.br/privkey.pem; # managed by Certbot
	ssl_trusted_certificate /etc/letsencrypt/live/seudominio.com.br/chain.pem;

	# Improve HTTPS performance with session resumption
	ssl_session_cache shared:SSL:10m;
	ssl_session_timeout 5m;

	# Enable server-side protection against BEAST attacks
	ssl_prefer_server_ciphers on;
	ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;

	# Disable SSLv3
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

	# Diffie-Hellman parameter for DHE ciphersuites
	# $ sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
	ssl_dhparam /etc/ssl/certs/dhparam.pem;

	# Enable HSTS (https://developer.mozilla.org/en-US/docs/Security/HTTP_Strict_Transport_Security)
	add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";

	# Enable OCSP stapling (http://blog.mozilla.org/security/2013/07/29/ocsp-stapling-in-firefox)
	ssl_stapling on;
	ssl_stapling_verify on;
	resolver 8.8.8.8 8.8.4.4 valid=300s;
	resolver_timeout 5s;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html index.php;

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