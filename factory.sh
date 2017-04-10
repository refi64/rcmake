#:DEPENDS git:project-rootbox/rootbox-factories///dev/cmake.sh
#:DEPENDS git:project-rootbox/rootbox-factories///dev/crystal.sh
sudo apk add ninja
curl -L https://goo.gl/FQKLvw | sh

# Generate and modify default ~/.rcmake.yml to use GCC.
cd `mktemp -d`
touch CMakeLists.txt
rcmake . >/dev/null 2>&1 ||:
sed -i 's/suite: clang/suite: gcc/' ~/.rcmake.yml
