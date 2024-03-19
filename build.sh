go get -u
go build -trimpath -ldflags "-s -w -extldflags -static -X $(go mod why | grep -v ^#)/cmd.GitCommit=$(git rev-parse --short HEAD^) -X $(go mod why | grep -v ^#)/cmd.Version=$(git show HEAD^ --pretty=format:"%ci" | head -1 | awk '{print $1}')"
if "./${PWD##*/}" version 2>/dev/null; then
  "./${PWD##*/}" tls cert create
  openssl x509 -in server.pem -enddate -noout
else
  tar -zcf "${PWD##*/}.tgz" "${PWD##*/}"
fi
