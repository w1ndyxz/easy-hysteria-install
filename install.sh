#!/bin/bash
SALAMANDER_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 25)
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 25)


read -p "Domain: " DOMAIN
read -p "Obfuscation or Masquerade (1 or 2): " STEALTH_TYPE

if [ "$STEALTH_TYPE" == "2" ]; then
    read -p "Masquerade type (file or proxy): " MASQUERADE_TYPE
    if [ "$MASQUERADE_TYPE" == "proxy" ]; then
        read -p "Masquerade proxy (default: html-flags.com): " PROXY_SITE
        PROXY_SITE=${PROXY_SITE:-html-flags.com}
    fi
fi

# sudo apt update && sudo apt upgrade -y
sudo apt install nano certbot -y

sudo certbot certonly --standalone -d $DOMAIN --email balls@gmail.com --agree-tos --no-eff-email --non-interactive
sudo chmod -R 755 /etc/letsencrypt/live/ && sudo chmod -R 755 /etc/letsencrypt/archive/


bash <(curl -fsSL https://get.hy2.sh/)


CONFIG_FILE="/etc/hysteria/config.yaml"
sudo mkdir -p /etc/hysteria/

cat <<EOF | sudo tee $CONFIG_FILE > /dev/null
listen: :443
tls:
  cert: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/$DOMAIN/privkey.pem
auth:
  type: password
  password: $PASSWORD
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 60s
  keepAlivePeriod: 10s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false
ignoreClientBandwidth: false
speedTest: false
disableUDP: false
udpIdleTimeout: 30s
resolver:
  type: tls
  tls:
    addr: 1.1.1.1:853
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false
EOF


if [ "$STEALTH_TYPE" == "1" ]; then
    cat <<EOF | sudo tee -a $CONFIG_FILE > /dev/null
obfs:
  type: salamander
  salamander:
    password: $SALAMANDER_PASS
EOF
    URL="hy2://$PASSWORD@$DOMAIN:443?obfs=salamander&obfs-password=$SALAMANDER_PASS#$DOMAIN"
else
    if [ "$MASQUERADE_TYPE" == "file" ]; then
        sudo mkdir -p /www/hysteria_easy
        cat <<'HTML_EOF' | sudo tee /www/hysteria_easy/index.html > /dev/null
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>До Нового Года осталось...</title>
    <style>
        :root { --bg-color: #0a0a0a; --text-color: #ffffff; --accent-color: #333333; }
        body { margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 90vh; background-color: var(--bg-color); color: var(--text-color); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; overflow: hidden; }
        .container { text-align: center; }
        h1 { font-weight: 200; font-size: 1.5rem; letter-spacing: 0.3rem; text-transform: uppercase; margin-bottom: 3rem; opacity: 0.8; }
        #countdown { display: flex; gap: 2rem; }
        .time-block { display: flex; flex-direction: column; align-items: center; min-width: 80px; }
        .number { font-size: 4rem; font-weight: 300; line-height: 1; }
        .label { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1rem; margin-top: 0.5rem; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1 id="title">New Year Countdown</h1>
        <div id="countdown">
            <div class="time-block"><div class="number" id="days">00</div><div class="label">Дней</div></div>
            <div class="time-block"><div class="number" id="hours">00</div><div class="label">Часов</div></div>
            <div class="time-block"><div class="number" id="minutes">00</div><div class="label">Минут</div></div>
            <div class="time-block"><div class="number" id="seconds">00</div><div class="label">Секунд</div></div>
        </div>
    </div>
    <script>
        function updateCountdown() {
            const currentYear = new Date().getFullYear();
            const nextYear = currentYear + 1;
            const newYearTime = new Date(`January 01 ${nextYear} 00:00:00`);
            const currentTime = new Date();
            const diff = newYearTime - currentTime;
            const d = Math.floor(diff / 1000 / 60 / 60 / 24);
            const h = Math.floor(diff / 1000 / 60 / 60) % 24;
            const m = Math.floor(diff / 1000 / 60) % 60;
            const s = Math.floor(diff / 1000) % 60;
            document.getElementById('days').innerHTML = d;
            document.getElementById('hours').innerHTML = h < 10 ? '0' + h : h;
            document.getElementById('minutes').innerHTML = m < 10 ? '0' + m : m;
            document.getElementById('seconds').innerHTML = s < 10 ? '0' + s : s;
            document.getElementById('title').innerText = `До ${nextYear} года осталось`;
        }
        setInterval(updateCountdown, 1000);
        updateCountdown();
    </script>
</body>
</html>
HTML_EOF
        cat <<EOF | sudo tee -a $CONFIG_FILE > /dev/null
masquerade:
  type: file
  file:
    dir: /www/hysteria_easy
EOF
    else
        cat <<EOF | sudo tee -a $CONFIG_FILE > /dev/null
masquerade:
  type: proxy
  proxy:
    url: https://$PROXY_SITE
    rewriteHost: true
  listenHTTPS: :443
  forceHTTPS: true
EOF
    fi
    URL="hy2://$PASSWORD@$DOMAIN:443#$DOMAIN"
fi


sudo systemctl enable hysteria-server.service
sudo systemctl restart hysteria-server.service


clear
echo "=============================================================="
echo "Hysteria 2 Installation Complete"
echo ""
echo "$URL"
echo "=============================================================="
sudo systemctl status hysteria-server.service --no-pager
