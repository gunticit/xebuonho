module github.com/xebuonho/services/matching-service

go 1.22

require (
	github.com/redis/go-redis/v9 v9.5.1
	github.com/xebuonho/pkg v0.0.0
	google.golang.org/grpc v1.62.1
)

replace github.com/xebuonho/pkg => ../../pkg
