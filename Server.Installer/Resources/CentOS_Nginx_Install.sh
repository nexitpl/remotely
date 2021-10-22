#!/bin/bash
echo "Thanks for trying nex-Remote!"
echo

Args=( "$@" )
ArgLength=${#Args[@]}

for (( i=0; i<${ArgLength}; i+=2 ));
do
    if [ "${Args[$i]}" = "--host" ]; then
        HostName="${Args[$i+1]}"
    elif [ "${Args[$i]}" = "--approot" ]; then
        AppRoot="${Args[$i+1]}"
    fi
done

if [ -z "$AppRoot" ]; then
    read -p "Enter path where the nex-Remote server files should be installed (typically /var/www/nex-Remote): " AppRoot
    if [ -z "$AppRoot" ]; then
        AppRoot="/var/www/nex-Remote"
    fi
fi

if [ -z "$HostName" ]; then
    read -p "Enter server host (e.g. https://remote.nex-it.pl): " HostName
fi

echo "Using $AppRoot as the nex-Remote website's content directory."

yum update
yum -y install curl
yum -y install software-properties-common
yum -y install gnupg

# Install .NET Core Runtime.
sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm

yum -y install apt-transport-https
yum -y update
yum -y install aspnetcore-runtime-5.0


 # Install other prerequisites.
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install yum-utils
yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
yum -y install unzip
yum -y install acl
yum -y install libc6-dev
yum -y install libgdiplus


# Set permissions on nex-Remote files.
setfacl -R -m u:apache:rwx $AppRoot
chown -R apache:apache $AppRoot
chmod +x "$AppRoot/nex-Remote_Server"


# Install Nginx
yum -y install nginx

systemctl start nginx


# Configure Nginx
nginxConfig="server {
    listen        80;
    server_name   $HostName *.$HostName;
    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection close;
        proxy_set_header   Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /_blazor {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    location /AgentHub {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /ViewerHub {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    location /CasterHub {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}"

echo "$nginxConfig" > /etc/nginx/conf.d/nexRemote.conf

# Test config.
nginx -t

# Reload.
nginx -s reload


# Create service.

serviceConfig="[Unit]
Description=nex-Remote Server

[Service]
WorkingDirectory=$AppRoot
ExecStart=/usr/bin/dotnet $AppRoot/nex-Remote_Server.dll
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
SyslogIdentifier=nexRemote
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target"

echo "$serviceConfig" > /etc/systemd/system/nex-Remote.service


# Enable service.
systemctl enable nex-Remote.service
# Start service.
systemctl start nex-Remote.service

firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

# Install Certbot and get SSL cert.
yum -y install certbot python3-certbot-nginx

certbot --nginx