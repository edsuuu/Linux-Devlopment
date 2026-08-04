
[Voltar](../README.md)

## Gerar Certificado SSL

```bash
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
```

```bash
sudo apt-get install certbot -y

OU 

sudo snap install certbot --classic
```

```bash
sudo service nginx stop
```

```bash
sudo certbot certonly --standalone -d seudominio.com.br
```

```bash
sudo service nginx start
```

- Para renovar caso o certificado expire

```bash
sudo certbot renew
```