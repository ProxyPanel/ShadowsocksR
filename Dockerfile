FROM python:3.14-alpine

ENV SERVER_ADDR     0.0.0.0
ENV SERVER_PORT     51348
ENV PASSWORD        psw
ENV METHOD          aes-128-ctr
ENV PROTOCOL        auth_aes128_md5
ENV PROTOCOLPARAM   32
ENV OBFS            tls1.2_ticket_auth_compatible
ENV TIMEOUT         300
ENV DNS_ADDR        8.8.8.8
ENV DNS_ADDR_2      8.8.4.4

RUN apk add --no-cache libsodium

COPY . /app

WORKDIR /app/shadowsocks

EXPOSE $SERVER_PORT

# 命令行只取这六个变量，其余运行参数来自 /app/config.json；DNS_ADDR/DNS_ADDR_2 不参与单用户入口
CMD ["sh", "-c", "exec python server.py -p \"$SERVER_PORT\" -k \"$PASSWORD\" -m \"$METHOD\" -O \"$PROTOCOL\" -o \"$OBFS\" -G \"$PROTOCOLPARAM\""]
