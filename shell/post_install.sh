APPS="$(grep -Ev '^#|^$' ./to_install.txt | xargs)"
echo $APPS
