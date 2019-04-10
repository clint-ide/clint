# syntax=docker/dockerfile:experimental

FROM adoptopenjdk/openjdk11:slim as lsp
WORKDIR /lsp
COPY extensions/flogo/lsp/ .
RUN --mount=type=cache,id=gradle,target=/root/.gradle ./gradlew build --no-daemon

FROM node:10-slim as ide
RUN apt-get update -qq && apt-get install -qq --no-install-recommends python make g++ unzip
WORKDIR /ide
COPY lerna.json package.json yarn.lock ./
COPY extensions/flogo/theia-extension ./extensions/flogo/theia-extension
COPY --from=lsp /lsp/io.flogo.lsp.ide/build/distributions/flogo-language-server.zip ./extensions/flogo/lsp/io.flogo.lsp.ide/build/distributions/
COPY ide/web ./ide/web
RUN yarn && rm -rf /ide/extensions/flogo/lsp

FROM golang:1.14.2 as go
ARG CLI_VERSION=0.9.99
ENV GOPATH=/go
RUN git clone https://github.com/debovema/cli.git && cd cli && git checkout v${CLI_VERSION} && go generate ./... && go install ./...

FROM clintide/clint-docker:0.0.1
RUN addgroup -S clint && adduser -S clint -G clint
ENV GOPATH=/clint/go
ENV PATH="${PATH}:${GOROOT}/bin:${GOPATH}/bin"
COPY --chown=clint:clint --from=ide /ide /clint/clint-ide
COPY --chown=clint:clint --from=go /go/bin/flogo /clint/go/bin/flogo
USER clint
RUN (curl -fsSL https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | zsh || true) && sed -i 's|ZSH_THEME="[^\"]*"|ZSH_THEME="ys"|' /home/clint/.zshrc
WORKDIR /home/clint
EXPOSE 3000
CMD ["yarn", "--cwd", "/clint/clint-ide/ide/web", "start", "--hostname", "0.0.0.0"]
