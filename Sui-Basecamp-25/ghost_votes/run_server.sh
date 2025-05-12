set -eux

cd framework/chall && sui move build && cd .. && RUST_BACKTRACE=1 cargo r --release
