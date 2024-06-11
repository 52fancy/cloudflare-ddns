# cloudflare-ddns
cloudflare ddns


# GO语言版本
````
Usage: ./ddns CFKEY 1234567890 CFUSER user@example.com CFZONE_NAME example.com CFRECORD_NAME host.example.com CFRECORD_TYPE A|AAAA|Both
````
## 自行编译

### amd64
````
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go
````
### arm64
````
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go
````
### armv7
````
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go
````
### mipsle
````
CGO_ENABLED=0 GOOS=linux GOARCH=mipsle go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go
````
