#!/usr/bin/env bash
set -euo pipefail

# ---- Always work under HOME ----
if [[ "${EUID}" -eq 0 ]]; then
  echo "Please run this script as a regular user (no sudo)."
  exit 1
fi
cd "${HOME:?}"

echo "==> Working dir: $(pwd)"

echo "==> Checking distro ..."
source /etc/os-release
echo "Detected: $NAME $VERSION ($UBUNTU_CODENAME)"

if [[ "${UBUNTU_CODENAME}" != "noble" ]]; then
  echo "This script targets Ubuntu 24.04 (noble). Detected: ${UBUNTU_CODENAME}"
  echo "Abort. Please use Ubuntu 24.04 in WSL."
  exit 1
fi

echo "==> Updating apt & installing base tools ..."
sudo apt-get update
sudo apt-get install -y software-properties-common curl gnupg lsb-release locales ca-certificates

echo "==> Ensuring UTF-8 locale ..."
sudo locale-gen en_US en_US.UTF-8 || true
sudo update-locale LANG=en_US.UTF-8

echo "==> Adding ROS 2 (packages.ros.org) key & repo ..."
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  | sudo tee /usr/share/keyrings/ros-archive-keyring.gpg >/dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu ${UBUNTU_CODENAME} main" \
| sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null

echo "==> Adding OSRF Gazebo key & repo (ubuntu-stable) ..."

sudo rm -f /usr/share/keyrings/gazebo-archive-keyring.gpg || true
sudo rm -f /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg || true
sudo rm -f /etc/apt/sources.list.d/gazebo-stable.list || true

curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
  | sudo tee /usr/share/keyrings/gazebo-archive-keyring.gpg >/dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gazebo-archive-keyring.gpg] \
https://packages.osrfoundation.org/gazebo/ubuntu-stable ${UBUNTU_CODENAME} main" \
| sudo tee /etc/apt/sources.list.d/gazebo-stable.list >/dev/null

echo "==> apt update ..."
sudo apt-get update

echo "==> Installing ROS 2 Jazzy desktop + Nav2 + ros_gz bridge + build tools ..."
sudo apt-get install -y \
  ros-jazzy-desktop \
  ros-jazzy-navigation2 \
  ros-jazzy-nav2-bringup \
  ros-jazzy-ros-gz \
  python3-colcon-common-extensions \
  ros-dev-tools \
  git

echo "==> Installing Gazebo Sim (Ionic) ..."
sudo apt-get install -y gz-ionic

echo "==> Appending ROS environment to ~/.bashrc (idempotent) ..."
if ! grep -q 'source /opt/ros/jazzy/setup.bash' ~/.bashrc ; then
  echo 'source /opt/ros/jazzy/setup.bash' >> ~/.bashrc
fi

if ! grep -q 'ROS_DOMAIN_ID=' ~/.bashrc ; then
  echo 'export ROS_DOMAIN_ID=11' >> ~/.bashrc
fi

if ! grep -q 'LIBGL_ALWAYS_SOFTWARE' ~/.bashrc ; then
  cat <<'EOF' >> ~/.bashrc

# --- Gazebo/RViz fallback (uncomment if GUI black screen in WSLg) ---
# export LIBGL_ALWAYS_SOFTWARE=1
EOF
fi

# ---- Create and build a clean ROS2 workspace under HOME ----
echo "==> Creating a clean colcon workspace and first build ..."
mkdir -p "${HOME}/catkin_ws/src"
pushd "${HOME}/catkin_ws" >/dev/null

colcon build || true
popd >/dev/null

# ---- Source workspace in bashrc (idempotent) ----
if ! grep -q 'source ~/catkin_ws/install/setup.bash' ~/.bashrc ; then
  echo 'source ~/catkin_ws/install/setup.bash' >> ~/.bashrc
fi

echo "==> Done."
echo
echo "Open two terminal, then verify:"
echo "  rviz2"
echo "  gz sim shapes.sdf"
echo
echo "Workspace ready at: ~/catkin_ws"