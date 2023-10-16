FROM rust:1.73-alpine3.17

ENV LUA_VERSION 5.3
ENV LUA_VERSION_STYLUA 53

RUN apk --no-cache add \
    lua${LUA_VERSION} \
    lua${LUA_VERSION}-dev \
    build-base \
    wget \
    && rm -rf /var/cache/apt/*

RUN echo "alias lua='lua${LUA_VERSION}'" > ~/.ashrc && source ~/.ashrc

RUN wget https://luarocks.org/releases/luarocks-3.9.2.tar.gz
RUN tar zxpf luarocks-3.9.2.tar.gz

WORKDIR /luarocks-3.9.2
RUN ./configure --lua-version=${LUA_VERSION}
RUN make
RUN make install

RUN luarocks install luacheck

RUN cargo install stylua --features lua${LUA_VERSION_STYLUA}

WORKDIR /
RUN ln -s /usr/bin/lua5.3 lua && mv lua /usr/local/bin/
RUN ln -s /luarocks-3.9.2/lua_modules/bin/luacheck luacheck && mv luacheck /usr/local/bin/

WORKDIR /workdir

CMD ash
