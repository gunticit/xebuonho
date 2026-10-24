module github.com/xebuonho/services/location-service

go 1.22

require (
	github.com/eclipse/paho.mqtt.golang v1.4.3
	github.com/redis/go-redis/v9 v9.5.1
	github.com/xebuonho/pkg v0.0.0
	google.golang.org/grpc v1.62.1
)

require (
	github.com/cespare/xxhash/v2 v2.2.0 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/go-redis/redis/v8 v8.11.5 // indirect
)

replace github.com/xebuonho/pkg => ../../pkg
