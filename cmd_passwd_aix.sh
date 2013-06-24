echo 'echo "CZ62140:Password01"|chpasswd -c' > chgpasswd.sh
echo 'echo "CZ62140:Password01"|chpasswd -f ADMCHG' > chgpasswd.sh
chmod a+x chgpasswd.sh
echo 'Password01'|sudo -S ./chgpasswd.sh
rm -rf chgpasswd.sh
