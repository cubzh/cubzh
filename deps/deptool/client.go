package deptool

import (
	"fmt"

	"github.com/voxowl/objectstorage"
	"github.com/voxowl/objectstorage/digitalocean"
)

const (
	defaultDigitalOceanSpacesAuthKey    = "DO8019TZD8N66GJGUEE3"
	defaultDigitalOceanSpacesAuthSecret = "OVVGXIdaEXRG8TPi2/TmI3Ji/h56nZgetMxeYw9aXlk"
	defaultDigitalOceanSpacesRegion     = "nyc3"
	defaultDigitalOceanSpacesBucket     = "cubzh-deps"
)

type DigitalOceanObjectStorageClientOpts struct {
	AuthKey    string // optional
	AuthSecret string // optional
	Region     string // optional
	Bucket     string // optional
}

func NewDigitalOceanObjectStorageClient(opts DigitalOceanObjectStorageClientOpts) (objectstorage.ObjectStorage, error) {

	// if only one of the two is set, return an error
	if (opts.AuthKey == "" && opts.AuthSecret != "") || (opts.AuthKey != "" && opts.AuthSecret == "") {
		return nil, fmt.Errorf("opts.AuthKey and opts.AuthSecret must be both set (or not set at all)")
	}

	// credentials
	authKey := opts.AuthKey
	authSecret := opts.AuthSecret
	if authKey == "" && authSecret == "" {
		authKey = defaultDigitalOceanSpacesAuthKey
		authSecret = defaultDigitalOceanSpacesAuthSecret
	}

	// region & bucket
	region := opts.Region
	bucket := opts.Bucket
	if region == "" {
		region = defaultDigitalOceanSpacesRegion
	}
	if bucket == "" {
		bucket = defaultDigitalOceanSpacesBucket
	}

	// Create the object storage client
	objectStorageClient, err := digitalocean.NewDigitalOceanObjectStorage(
		digitalocean.DigitalOceanConfig{
			Region:     region,
			Bucket:     bucket,
			AuthKey:    authKey,
			AuthSecret: authSecret,
		},
		digitalocean.DigitalOceanObjectStorageOpts{
			UsePathStyle: true,
		},
	)
	return objectStorageClient, err
}
