FROM rust:latest

RUN apt-get update && apt-get install -qy clang libudev-dev nodejs npm tmux vim neovim git zsh nano wget cmake gcc libssl-dev libclang-dev curl libpq-dev screen
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

RUN rustup component add rustfmt
RUN rustup update stable

WORKDIR /home

RUN rustup update stable
RUN wget https://github.com/MystenLabs/sui/releases/download/devnet-v1.47.0/sui-devnet-v1.47.0-ubuntu-aarch64.tgz
RUN tar -xzf sui-devnet-v1.47.0-ubuntu-aarch64.tgz
RUN rm sui-devnet-v1.47.0-ubuntu-aarch64.tgz
RUN chmod +x sui 

RUN mv sui /bin

WORKDIR /
RUN git clone https://github.com/asymptotic-code/sui-ctf-framework.git

ADD ./ /work

WORKDIR /work/framework/chall
RUN sui move build

WORKDIR /work/framework

# refresh from dummy
RUN touch src/main.rs
RUN cargo build --locked --release

CMD cargo r --release
