module github.com/xebuonho/services/notification-service

go 1.22

require github.com/xebuonho/pkg v0.0.0

require (
	github.com/google/uuid v1.6.0 // indirect
	github.com/klauspost/compress v1.17.7 // indirect
	github.com/pierrec/lz4/v4 v4.1.21 // indirect
	github.com/segmentio/kafka-go v0.4.47 // indirect
	golang.org/x/net v0.22.0 // indirect
)

replace github.com/xebuonho/pkg => ../../pkg
