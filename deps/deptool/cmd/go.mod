module github.com/cubzh/cubzh/deps/deptool/cmd

go 1.24.1

// Use the local copies of packages
replace github.com/cubzh/cubzh/deps/deptool v0.0.1 => ../

replace github.com/cubzh/cubzh/deps/deptool/utils v0.0.1 => ../utils

require (
	github.com/cubzh/cubzh/deps/deptool v0.0.1
	github.com/spf13/cobra v1.9.1
	github.com/voxowl/objectstorage v0.0.3
)

require (
	github.com/aws/aws-sdk-go-v2 v1.36.2 // indirect
	github.com/aws/aws-sdk-go-v2/aws/protocol/eventstream v1.6.10 // indirect
	github.com/aws/aws-sdk-go-v2/credentials v1.17.60 // indirect
	github.com/aws/aws-sdk-go-v2/internal/configsources v1.3.33 // indirect
	github.com/aws/aws-sdk-go-v2/internal/endpoints/v2 v2.6.33 // indirect
	github.com/aws/aws-sdk-go-v2/internal/v4a v1.3.33 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/accept-encoding v1.12.3 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/checksum v1.6.1 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/presigned-url v1.12.14 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/s3shared v1.18.14 // indirect
	github.com/aws/aws-sdk-go-v2/service/s3 v1.77.1 // indirect
	github.com/aws/smithy-go v1.22.2 // indirect
	github.com/cubzh/cubzh/deps/deptool/utils v0.0.1 // indirect
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/pflag v1.0.6 // indirect
)
