# Manual install only (README "Alternative: manual install"): source this in each new terminal
# before building: `source env.sh`. Everything lives in ~/ncs; cleanup-ncs.sh removes it.
source ~/ncs/.venv/bin/activate
export ZEPHYR_SDK_INSTALL_DIR=~/ncs/zephyr-sdk-0.17.4
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
source ~/ncs/v3.2.0/zephyr/zephyr-env.sh
