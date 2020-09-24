name=$1

echo "Generate CA"
echo "*************************"
echo "*************************"
echo "*************************"
openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout $name.key -out $name.pem -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost.local"
openssl x509 -outform pem -in $name.pem -out $name.crt

echo "*************************"
echo "*************************"
echo "*************************"

echo "Generate localhost crt and key"
echo "*************************"
echo "*************************"
echo "*************************"
openssl req -new -nodes -newkey rsa:2048 -keyout localhost.key -out localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost.local"
openssl x509 -req -sha256 -days 1024 -in localhost.csr -CA $name.pem -CAkey $name.key -CAcreateserial -extfile domains.ext -out localhost.crt
echo "*************************"
echo "*************************"
echo "*************************"


echo "*************************"
echo "*************************"
echo "*************************"
echo "*************************"
echo "*************************"
echo "Delete files that aren't needed"

echo "*************************"
echo "*************************"
echo "*************************"
echo "*************************"
echo "*************************"
